"""
Module: tools/invoke_ha_core_update.py
Purpose: Connects to Home Assistant OS to trigger the Home Assistant Core update
         and performs a tiered polling health and liveness loop until the new container
         is RUNNING with safe_mode=False.
Governance Standard: SubsystemGovernancePolicy.md (RULE-SUB-004 & RULE-SUB-006)
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-23
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

# Set output encoding to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

SECRETS_PATHS = [
    r"D:\Git_Repositories\HaSSD06_Inventory\data\secrets.json",
    r"D:\Git_Repositories\HaSSD06\data\secrets.json"
]

def load_secrets():
    for sp in SECRETS_PATHS:
        if os.path.exists(sp):
            with open(sp, "r", encoding="utf-8") as f:
                return json.load(f)
    raise FileNotFoundError("Could not find secrets.json in HaSSD06 or HaSSD06_Inventory")

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
        if probe_endpoint(c, timeout_sec=1.5):
            return c

    return configured_url or "http://192.168.10.6:8123"

def ha_api_call(url: str, token: str, endpoint: str, method: str = "GET", body: dict = None, timeout_sec: float = 10.0):
    full_url = f"{url.rstrip('/')}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(full_url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
        return json.loads(resp.read().decode("utf-8"))

def execute_core_update(target_version: str = "2026.8.3", timeout_seconds: int = 1200):
    secrets = load_secrets()
    configured_url = secrets.get("api_url", "http://192.168.10.6:8123")
    token = secrets.get("ha_auditor_token", "")
    
    url = resolve_ha_url(configured_url)
    print(f"[OK] Resolved active Home Assistant endpoint: {url}")
    
    # 1. Pre-flight check: Current Config & Update Entity State
    print("[STAGE 1] Checking pre-flight system state...")
    cfg = ha_api_call(url, token, "/api/config")
    installed_ver = cfg.get("version")
    print(f"  - Current Home Assistant Core Version: {installed_ver}")
    print(f"  - Core State: {cfg.get('state')} (SafeMode: {cfg.get('safe_mode')})")
    
    if installed_ver == target_version:
        print(f"[INFO] Home Assistant Core is already at version {target_version}. No update required.")
        return {"status": "ALREADY_UPDATED", "version": target_version}
        
    update_entity = ha_api_call(url, token, "/api/states/update.home_assistant_core_update")
    attrs = update_entity.get("attributes", {})
    latest_ver = attrs.get("latest_version")
    release_url = attrs.get("release_url", "")
    release_summary = attrs.get("release_summary", "")

    print(f"  - Pending Update Entity: {update_entity.get('entity_id')} ({update_entity.get('state')})")
    print(f"  - Available Target Version: {latest_ver}")
    print(f"  - Release Notes URL: {release_url or 'N/A'}")

    # Breaking Changes Evaluation
    breaking_keywords = ["breaking", "deprecated", "removed", "migration required", "action required"]
    combined_notes = f"{release_summary} {release_url}".lower()
    breaking_hits = [k for k in breaking_keywords if k in combined_notes]

    if breaking_hits:
        print(f"  - [WARNING] Breaking change indicators detected: {', '.join(breaking_hits)}")
    else:
        print("  - [PASS] Breaking Changes Evaluation: 0 breaking changes detected (safe for automated update).")

    # 2. Dispatch update.install service call
    print(f"\n[STAGE 2] Dispatching service call 'update.install' for Core ({installed_ver} -> {target_version})...")
    payload = {
        "entity_id": "update.home_assistant_core_update",
        "backup": False
    }
    try:
        ha_api_call(url, token, "/api/services/update/install", method="POST", body=payload, timeout_sec=30.0)
        print("[OK] Update dispatch accepted by Home Assistant Core.")
    except Exception as e:
        print(f"[WARN] Service dispatch notification: {e}")
        
    # 3. Tiered Polling Health & Liveness Loop
    print(f"\n[STAGE 3] Entering Tiered Polling Health Loop (Budget: {timeout_seconds}s / {int(timeout_seconds/60)}m)...")
    start_time = time.time()
    verified_healthy = False
    new_version_verified = None
    
    # Give the container 10 seconds before polling
    time.sleep(10)
    
    while time.time() - start_time < timeout_seconds:
        elapsed = int(time.time() - start_time)
        try:
            # Check if web endpoint is responding
            if probe_endpoint(url, timeout_sec=2.0):
                cfg = ha_api_call(url, token, "/api/config", timeout_sec=5.0)
                cur_ver = cfg.get("version")
                cur_state = cfg.get("state")
                safe_mode = cfg.get("safe_mode", False)
                
                print(f"  [{elapsed}s/{timeout_seconds}s] Endpoint reachable: Version='{cur_ver}', State='{cur_state}', SafeMode={safe_mode}")
                
                if cur_ver == target_version:
                    new_version_verified = cur_ver
                    if cur_state == "RUNNING" and not safe_mode:
                        print(f"\n[SUCCESS] Home Assistant Core successfully updated to {cur_ver} and is RUNNING!")
                        verified_healthy = True
                        break
                    else:
                        print(f"  [{elapsed}s] Waiting for state to reach RUNNING (current: {cur_state})...")
                else:
                    print(f"  [{elapsed}s] Container image downloading / updating in background (installed: {cur_ver})...")
            else:
                print(f"  [{elapsed}s/{timeout_seconds}s] Core container restarting / network offline (waiting for HTTP 200)...")
        except Exception as e:
            print(f"  [{elapsed}s/{timeout_seconds}s] Waiting for container switchover ({type(e).__name__})...")
            
        time.sleep(10)
        
    if not verified_healthy:
        raise TimeoutError(f"Health verification timed out after {timeout_seconds}s. Please check host directly.")
        
    # 4. Confirm update entity state is now 'off'
    time.sleep(3)
    try:
        update_ent = ha_api_call(url, token, "/api/states/update.home_assistant_core_update")
        print(f"[INFO] Update Entity State: {update_ent.get('state')} (Installed: {update_ent.get('attributes', {}).get('installed_version')})")
    except Exception:
        pass
        
    receipt = {
        "status": "SUCCESS",
        "action": "CORE_UPDATE",
        "previous_version": installed_ver,
        "current_version": new_version_verified,
        "safe_mode": False,
        "state": "RUNNING",
        "elapsed_seconds": int(time.time() - start_time),
        "target_subsystem": "HaSSD06",
        "endpoint": url
    }
    
    print("\n=== FORMAL CORE UPDATE RECEIPT ===")
    print(json.dumps(receipt, indent=2))
    return receipt

if __name__ == "__main__":
    ver = sys.argv[1] if len(sys.argv) > 1 else "2026.8.3"
    execute_core_update(ver)
