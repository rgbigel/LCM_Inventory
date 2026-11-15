"""
Module: extract_ha_update_crps.py
Purpose: Queries Home Assistant OS update entities, extracts release notes and breaking changes, and structures them into Change Request Proposals (CRPs).
Path: HaSSD06/extract_ha_update_crps.py
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-21
"""

import json
import os
import re
import sys
import urllib.request

# Ensure UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

def load_secrets():
    secrets_path = r'D:\Git_Repositories\HaSSD06_Inventory\data\secrets.json'
    if not os.path.exists(secrets_path):
        raise FileNotFoundError(f"Secrets file not found at: {secrets_path}")
    with open(secrets_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def probe_endpoint(url: str, timeout_sec: float = 1.5) -> bool:
    try:
        req = urllib.request.Request(f"{url.rstrip('/')}/manifest.json", headers={"User-Agent": "LCM-Prober"})
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            return resp.status == 200
    except Exception:
        return False

def resolve_ha_url(configured_url: str = "") -> str:
    candidates = []
    if configured_url:
        candidates.append(configured_url.rstrip("/"))
    if os.getenv("HA_URL"):
        candidates.append(os.getenv("HA_URL").rstrip("/"))

    defaults = [
        "http://192.168.10.6:8123",
        "http://192.168.10.106:8123",
        "http://HaSSD06.local:8123",
        "http://hassd06:8123"
    ]
    for d in defaults:
        if d not in candidates:
            candidates.append(d)

    for c in candidates:
        if probe_endpoint(c, timeout_sec=1.2):
            return c

    return configured_url or "http://192.168.10.6:8123"

def fetch_states(api_url, token):
    active_url = resolve_ha_url(api_url)
    url = f"{active_url.rstrip('/')}/api/states"
    req = urllib.request.Request(url, headers={
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode('utf-8'))

def analyze_breaking_changes(title, summary, release_url):
    combined_text = f"{title}\n{summary}\n{release_url}".lower()
    breaking_patterns = [
        r'\bbreaking\s+changes?\b',
        r'\bbreaking\b',
        r'\bdeprecated\b',
        r'\bremoved\b',
        r'\bmigration\s+required\b',
        r'\baction\s+required\b'
    ]
    
    findings = []
    for pattern in breaking_patterns:
        matches = re.findall(pattern, combined_text, re.IGNORECASE)
        if matches:
            findings.extend(matches)
            
    is_breaking = len(findings) > 0
    return is_breaking, list(set(findings))

def fetch_websocket_diagnostics(api_url, token):
    ws_url = api_url.rstrip('/').replace('http://', 'ws://').replace('https://', 'wss://') + '/api/websocket'
    try:
        import asyncio
        import websockets

        async def _query():
            async with websockets.connect(ws_url, open_timeout=4.0) as ws:
                await ws.recv()
                await ws.send(json.dumps({'type': 'auth', 'access_token': token}))
                auth_resp = json.loads(await ws.recv())
                if auth_resp.get('type') != 'auth_ok':
                    return [], []

                # 1. Repairs
                await ws.send(json.dumps({'id': 1, 'type': 'repairs/list_issues'}))
                repairs_data = json.loads(await ws.recv())
                issues = repairs_data.get('result', {}).get('issues', [])

                # 2. Config Entries
                await ws.send(json.dumps({'id': 2, 'type': 'config_entries/get'}))
                entries_data = json.loads(await ws.recv())
                entries = entries_data.get('result', [])

                return issues, entries

        return asyncio.run(_query())
    except Exception as e:
        print(f"[WARN] WebSocket diagnostics unavailable ({type(e).__name__}). Falling back to REST.")
        return [], []

def generate_crps():
    secrets = load_secrets()
    configured_url = secrets.get('api_url', 'http://192.168.10.6:8123')
    token = secrets.get('ha_auditor_token', '')

    api_url = resolve_ha_url(configured_url)
    print(f"Scanning for available updates & maintenance issues at: {api_url}...")
    states = fetch_states(api_url, token)
    repairs, config_entries = fetch_websocket_diagnostics(api_url, token)

    all_proposals = []

    # 1. Scan Software Updates
    update_entities = [s for s in states if s.get("entity_id", "").startswith("update.")]
    for u in update_entities:
        attrs = u.get("attributes", {})
        installed = attrs.get("installed_version")
        latest = attrs.get("latest_version")
        title = attrs.get("title") or attrs.get("friendly_name") or u["entity_id"]
        summary = attrs.get("release_summary") or ""
        release_url = attrs.get("release_url") or ""
        entity_id = u["entity_id"]

        if latest and installed and latest != installed:
            is_breaking, breaking_reasons = analyze_breaking_changes(title, summary, release_url)

            if is_breaking or "core" in entity_id or "homeassistant" in entity_id or "os" in entity_id:
                risk_level = "Critical" if is_breaking else "High"
            elif "zigbee2mqtt" in entity_id or "mosquitto" in entity_id or "openthread" in entity_id:
                risk_level = "High"
            elif "hacs" in entity_id:
                risk_level = "Medium"
            else:
                risk_level = "Low"

            crp = {
                "crp_id": f"CRP-UPDATE-{entity_id.replace('update.', '')}",
                "category": "software-update",
                "entity_id": entity_id,
                "title": title,
                "installed_version": installed,
                "target_version": latest,
                "risk_level": risk_level,
                "breaking_changes_detected": is_breaking,
                "breaking_indicators": breaking_reasons,
                "release_url": release_url,
                "summary": summary[:500] if summary else "No release summary provided in HA state payload.",
                "disposition": "pending-review"
            }
            all_proposals.append(crp)

    # 2. Scan Repairs & Deprecations (Maintenance / Re-customization)
    for issue in repairs:
        domain = issue.get("domain", "general")
        issue_id = issue.get("issue_id", "unknown")
        severity = issue.get("severity", "warning")
        breaks_in = issue.get("breaks_in_ha_version")
        learn_url = issue.get("learn_more_url", "")
        translation_key = issue.get("translation_key", issue_id)

        risk_level = "Critical" if breaks_in or severity == "error" else "Medium"
        title = f"Repair: {domain.upper()} - {translation_key.replace('_', ' ').title()}"

        crp = {
            "crp_id": f"CRP-MAINT-REPAIR-{domain}-{issue_id}",
            "category": "maintenance-repair",
            "domain": domain,
            "title": title,
            "severity": severity,
            "breaks_in_version": breaks_in,
            "risk_level": risk_level,
            "action_required": f"Deprecation or repair issue active in domain '{domain}'. Scheduled to break in HA {breaks_in}." if breaks_in else f"Active maintenance repair required: {translation_key}.",
            "learn_more_url": learn_url,
            "disposition": "pending-review"
        }
        all_proposals.append(crp)

    # 3. Scan Problem Config Entries (Real setup/auth errors, excluding intentional user ignores)
    problem_entries = [
        e for e in config_entries 
        if e.get("state") not in ("loaded",) and e.get("source") != "ignore" and not e.get("disabled_by")
    ]
    for pe in problem_entries:
        p_title = pe.get("title") or pe.get("domain")
        p_domain = pe.get("domain")
        p_state = pe.get("state")
        p_reason = pe.get("reason")
        p_id = pe.get("entry_id", "unknown")

        crp = {
            "crp_id": f"CRP-MAINT-CONFIG-{p_domain}-{p_id[:8]}",
            "category": "integration-setup",
            "domain": p_domain,
            "title": f"Integration Fault: {p_title} ({p_state})",
            "state": p_state,
            "reason": p_reason,
            "risk_level": "Medium",
            "action_required": f"Integration '{p_title}' failed with '{p_state}' state. Requires re-authentication, device check, or removal.",
            "disposition": "pending-review"
        }
        all_proposals.append(crp)

    # Sort proposals: Critical -> High -> Medium -> Low
    risk_weights = {"Critical": 1, "High": 2, "Medium": 3, "Low": 4}
    all_proposals.sort(key=lambda x: (risk_weights.get(x.get("risk_level", "Low"), 5), x.get("title", "")))

    out_dir = r'D:\Git_Repositories\HaSSD06_Inventory\data\proposals'
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, 'pending_update_crps.json')

    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump({
            "total_pending_proposals": len(all_proposals),
            "software_updates": len([p for p in all_proposals if p.get("category") == "software-update"]),
            "maintenance_repairs": len([p for p in all_proposals if p.get("category") == "maintenance-repair"]),
            "config_entry_issues": len([p for p in all_proposals if p.get("category") == "integration-setup"]),
            "proposals": all_proposals
        }, f, indent=2)

    print(f"\nDiscovered {len(all_proposals)} pending change request proposal(s):")
    print(f"  - Software Updates     : {len([p for p in all_proposals if p.get('category') == 'software-update'])}")
    print(f"  - Maintenance / Repairs: {len([p for p in all_proposals if p.get('category') == 'maintenance-repair'])}")
    print(f"  - Integration Setup    : {len([p for p in all_proposals if p.get('category') == 'integration-setup'])}")
    print(f"Output saved to: {out_file}\n")

    for p in all_proposals:
        cat = p.get("category")
        risk = p.get("risk_level", "Low")
        p_title = p.get("title", "")
        breaks = f" [BREAKS IN: {p.get('breaks_in_version')}]" if p.get("breaks_in_version") else ""
        print(f"  [{risk:<8}] [{cat:<18}] {p_title:<45}{breaks}")

if __name__ == '__main__':
    generate_crps()
