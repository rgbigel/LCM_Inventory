"""
Module: tools/extract_ha_central_registry.py
Purpose: Connects to Home Assistant OS via WebSocket API strictly as a READ-ONLY observer
         to extract the Central Registry (Device Registry, Config Entries, Area Registry, and Entity Registry).
Governance Invariant (RULE-SUB-007): This script is strictly non-modifying. It never mutates,
                                     writes, or alters the Home Assistant central registry.
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-21
"""

import asyncio
import json
import os
import sys

# Set output encoding to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

try:
    import websockets
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets"])
    import websockets

secrets_path = r"D:\Git_Repositories\HaSSD06_Inventory\data\secrets.json"
with open(secrets_path, "r", encoding="utf-8") as f:
    sec = json.load(f)

configured_url = sec.get("api_url", "http://192.168.10.6:8123")
token = sec.get("ha_auditor_token", "")

def get_candidate_ws_urls():
    candidates = [
        configured_url,
        "http://192.168.10.6:8123",
        "http://192.168.10.106:8123",
        "http://HaSSD06.local:8123",
        "http://hassd06:8123"
    ]
    seen = set()
    ws_urls = []
    for c in candidates:
        norm = c.rstrip("/")
        if norm not in seen:
            seen.add(norm)
            ws_url = norm.replace("http://", "ws://").replace("https://", "wss://") + "/api/websocket"
            ws_urls.append(ws_url)
    return ws_urls

async def fetch_central_registry():
    ws_urls = get_candidate_ws_urls()
    last_error = None

    for ws_url in ws_urls:
        try:
            async with websockets.connect(ws_url, open_timeout=2.0) as ws:
                auth_req = json.loads(await ws.recv())
                await ws.send(json.dumps({"type": "auth", "access_token": token}))
                auth_ok = json.loads(await ws.recv())
                if auth_ok.get("type") != "auth_ok":
                    raise PermissionError(f"HA WebSocket Auth Failed on {ws_url}: {auth_ok}")

                # 1. Device Registry (Deduplicated on device ID)
                await ws.send(json.dumps({"id": 1, "type": "config/device_registry/list"}))
                raw_devices = (json.loads(await ws.recv())).get("result", [])
                seen_dev_ids = set()
                devices = []
                for d in raw_devices:
                    dev_id = d.get("id")
                    if dev_id and dev_id not in seen_dev_ids:
                        seen_dev_ids.add(dev_id)
                        devices.append(d)

                # 2. Config Entries / Integrations (Deduplicated on entry ID)
                await ws.send(json.dumps({"id": 2, "type": "config_entries/get"}))
                raw_entries = (json.loads(await ws.recv())).get("result", [])
                seen_entry_ids = set()
                entries = []
                for e in raw_entries:
                    eid = e.get("entry_id") or f"{e.get('domain')}_{e.get('title')}"
                    if eid not in seen_entry_ids:
                        seen_entry_ids.add(eid)
                        entries.append(e)

                # 3. Area Registry (Deduplicated on Area ID or name)
                await ws.send(json.dumps({"id": 3, "type": "config/area_registry/list"}))
                raw_areas = (json.loads(await ws.recv())).get("result", [])
                seen_area_keys = set()
                areas = []
                for a in raw_areas:
                    area_key = (a.get("id") or a.get("name") or "").strip().lower()
                    if area_key and area_key not in seen_area_keys:
                        seen_area_keys.add(area_key)
                        areas.append(a)

                # 4. Entity Registry (Deduplicated on entity_id)
                await ws.send(json.dumps({"id": 4, "type": "config/entity_registry/list"}))
                raw_entities = (json.loads(await ws.recv())).get("result", [])
                seen_ent_ids = set()
                entities = []
                for ent in raw_entities:
                    ent_id = ent.get("entity_id")
                    if ent_id and ent_id not in seen_ent_ids:
                        seen_ent_ids.add(ent_id)
                        entities.append(ent)

                return {
                    "active_ws_endpoint": ws_url,
                    "devices": devices,
                    "config_entries": entries,
                    "areas": areas,
                    "entities": entities
                }
        except Exception as e:
            last_error = e
            continue

    raise ConnectionError(f"Failed to connect to any Home Assistant endpoint: {last_error}")

if __name__ == "__main__":
    data = asyncio.run(fetch_central_registry())
    print(json.dumps(data, indent=2, ensure_ascii=False))
