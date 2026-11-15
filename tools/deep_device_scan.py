"""
Module: deep_device_scan.py
Purpose: Generalized Deep Device & Integration Scanner for Home Assistant OS.
Scans and diagnoses devices, config entries, child entities, and attributes for any brand, ecosystem, or device name.
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-23
"""

import os
import sys
import json
import asyncio
import argparse
import urllib.request
import websockets

sys.stdout.reconfigure(encoding="utf-8")

def get_ha_token():
    token_paths = [
        r"D:\Git_Repositories\HaSSD06_Inventory\data\secrets.json",
        r"D:\Git_Repositories\HaSSD06\.ha_token"
    ]
    for p in token_paths:
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                content = f.read().strip()
                if p.endswith(".json"):
                    try:
                        data = json.loads(content)
                        return data.get("ha_auditor_token") or data.get("ha_token") or data.get("token")
                    except Exception:
                        pass
                else:
                    return content
    return None

def get_candidate_ws_urls():
    candidates = [
        "http://192.168.10.6:8123",
        "http://192.168.10.106:8123",
        "http://HaSSD06.local:8123",
        "http://hassd06:8123"
    ]
    ws_urls = []
    seen = set()
    for c in candidates:
        norm = c.rstrip("/")
        if norm not in seen:
            seen.add(norm)
            ws_url = norm.replace("http://", "ws://").replace("https://", "wss://") + "/api/websocket"
            ws_urls.append((norm, ws_url))
    return ws_urls

async def run_scan(target_query: str):
    token = get_ha_token()
    if not token:
        print("[ERROR] Home Assistant authentication token not found.")
        return

    ws_candidates = get_candidate_ws_urls()
    ws_conn = None
    active_http = None

    for http_url, ws_url in ws_candidates:
        try:
            ws = await websockets.connect(ws_url, open_timeout=2.0)
            await ws.recv() # auth required
            await ws.send(json.dumps({"type": "auth", "access_token": token}))
            auth_res = json.loads(await ws.recv())
            if auth_res.get("type") == "auth_ok":
                ws_conn = ws
                active_http = http_url
                break
            else:
                await ws.close()
        except Exception:
            continue

    if not ws_conn:
        print("[ERROR] Could not connect to Home Assistant via WebSocket across candidate endpoints.")
        return

    print("=" * 70)
    print(" 🔍 HOME ASSISTANT DEEP SCANNER")
    print(f" Target Query : '{target_query}'")
    print(f" Active Host  : {active_http}")
    print("=" * 70)

    try:
        # 1. Device Registry
        await ws_conn.send(json.dumps({"id": 1, "type": "config/device_registry/list"}))
        devices = (json.loads(await ws_conn.recv())).get("result", [])

        # 2. Config Entries
        await ws_conn.send(json.dumps({"id": 2, "type": "config_entries/get"}))
        config_entries = (json.loads(await ws_conn.recv())).get("result", [])

        # 3. Area Registry
        await ws_conn.send(json.dumps({"id": 3, "type": "config/area_registry/list"}))
        areas = (json.loads(await ws_conn.recv())).get("result", [])

        # 4. Entity Registry
        await ws_conn.send(json.dumps({"id": 4, "type": "config/entity_registry/list"}))
        entities = (json.loads(await ws_conn.recv())).get("result", [])

        # 5. REST States for live telemetry
        states_url = f"{active_http}/api/states"
        req = urllib.request.Request(states_url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            states = json.loads(resp.read().decode("utf-8"))
        states_by_id = {s["entity_id"]: s for s in states}

    finally:
        await ws_conn.close()

    # Lookups
    area_map = {a.get("area_id") or a.get("id"): a.get("name") for a in areas}

    q = target_query.lower()

    # Match Devices
    matched_devices = []
    for d in devices:
        name = (d.get("name_by_user") or d.get("name") or "").lower()
        mfg = (d.get("manufacturer") or "").lower()
        model = (d.get("model") or "").lower()
        dev_id = (d.get("id") or "").lower()
        if q in name or q in mfg or q in model or q == dev_id or (q in "shelly" and "shelly" in mfg) or (q in "tuya" and "tuya" in mfg):
            matched_devices.append(d)

    # Match Integrations / Config Entries
    matched_entries = []
    for e in config_entries:
        domain = (e.get("domain") or "").lower()
        title = (e.get("title") or "").lower()
        if q in domain or q in title:
            matched_entries.append(e)

    # Match Entities
    matched_entity_ids = set()
    matched_entities_info = []

    # Direct entity search
    for ent in entities:
        eid = (ent.get("entity_id") or "").lower()
        ename = (ent.get("name") or ent.get("original_name") or "").lower()
        platform = (ent.get("platform") or "").lower()
        dev_id = ent.get("device_id")

        is_dev_match = any(d.get("id") == dev_id for d in matched_devices)
        if q in eid or q in ename or q in platform or is_dev_match:
            matched_entity_ids.add(ent.get("entity_id"))
            matched_entities_info.append(ent)

    # Also check states
    for s in states:
        eid = s.get("entity_id", "")
        if eid not in matched_entity_ids:
            fname = (s.get("attributes", {}).get("friendly_name") or "").lower()
            if q in eid.lower() or q in fname:
                matched_entity_ids.add(eid)

    print(f"\n[1] MATCHED HARDWARE DEVICES ({len(matched_devices)} found):")
    if matched_devices:
        for idx, d in enumerate(matched_devices, 1):
            d_name = d.get("name_by_user") or d.get("name") or "Unnamed Device"
            d_mfg = d.get("manufacturer") or "Unknown"
            d_model = d.get("model") or "-"
            d_area = area_map.get(d.get("area_id"), "Unassigned Area")
            d_sw = d.get("sw_version") or "-"
            d_conns = d.get("connections", [])
            conns_str = ", ".join([f"{c[0]}: {c[1]}" for c in d_conns]) if d_conns else "-"
            print(f"  {idx}. {d_name}")
            print(f"     Manufacturer : {d_mfg} | Model: {d_model} | FW: {d_sw}")
            print(f"     Area / Room  : {d_area}")
            print(f"     Connections  : {conns_str}")
            print(f"     Device ID    : {d.get('id')}")
    else:
        print("  (No direct hardware device records matched query)")

    print(f"\n[2] MATCHED INTEGRATION CONFIG ENTRIES ({len(matched_entries)} found):")
    if matched_entries:
        for idx, e in enumerate(matched_entries, 1):
            print(f"  {idx}. Domain: '{e.get('domain')}' | Title: '{e.get('title')}' | State: {e.get('state')}")
            print(f"     Entry ID : {e.get('entry_id')}")
    else:
        print("  (No direct integration config entry records matched query)")

    print(f"\n[3] MATCHED LIVE ENTITIES & TELEMETRY ({len(matched_entity_ids)} found):")
    if matched_entity_ids:
        for idx, eid in enumerate(sorted(matched_entity_ids), 1):
            s = states_by_id.get(eid, {})
            st = s.get("state", "unknown")
            attrs = s.get("attributes", {})
            fname = attrs.get("friendly_name", eid)
            unit = attrs.get("unit_of_measurement", "")
            d_class = attrs.get("device_class", "-")
            val_str = f"{st} {unit}".strip()
            print(f"  {idx:2d}. {eid:<40} -> '{fname}'")
            print(f"      State: {val_str:<18} | Class: {d_class}")
            # Key diagnostic attributes
            diag_attrs = {k: v for k, v in attrs.items() if k in ("power", "energy", "voltage", "current", "temperature", "humidity", "battery", "linkquality", "rssi", "ip_address")}
            if diag_attrs:
                diag_str = ", ".join([f"{k}: {v}" for k, v in diag_attrs.items()])
                print(f"      Telemetry: {diag_str}")
    else:
        print("  (No entities matched query)")

    print("\n" + "=" * 70)
    print(" SCAN COMPLETED")
    print("=" * 70)

def main():
    parser = argparse.ArgumentParser(description="Generalized Home Assistant Deep Device & Integration Scanner")
    parser.add_argument("query", nargs="?", default="tuya", help="Brand, device name, model, integration domain, or entity query")
    parser.add_argument("--brand", dest="brand", help="Filter by brand name (e.g. Tuya, Shelly, AVM, Sonoff, Sonos, Nuki, Eufy, Govee)")
    parser.add_argument("--device", dest="device", help="Filter by device name or device ID")
    args = parser.parse_args()

    target = args.brand or args.device or args.query
    asyncio.run(run_scan(target))

if __name__ == "__main__":
    main()
