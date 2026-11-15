"""
Module: tools/invoke_ha_backup.py
Purpose: Connects to Home Assistant OS via WebSocket API to dispatch and monitor
         a native full system backup across configured storage agents (e.g. local + OneDrive).
Governance Standard: SubsystemGovernancePolicy.md (RULE-SUB-004 & RULE-SUB-006)
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-23
"""

import asyncio
import json
import os
import sys
import time

# Set output encoding to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

try:
    import websockets
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets"])
    import websockets

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

def get_candidate_ws_urls(configured_url):
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

async def run_backup(backup_name="HaSSD06_pre_change_baseline_20260823", timeout_seconds=600):
    secrets = load_secrets()
    configured_url = secrets.get("api_url", "http://192.168.10.6:8123")
    token = secrets.get("ha_auditor_token", "")
    
    ws_urls = get_candidate_ws_urls(configured_url)
    ws = None
    connected_url = None
    
    for url in ws_urls:
        try:
            conn = await websockets.connect(url, open_timeout=3.0)
            await conn.recv()
            await conn.send(json.dumps({"type": "auth", "access_token": token}))
            auth_resp = json.loads(await conn.recv())
            if auth_resp.get("type") == "auth_ok":
                ws = conn
                connected_url = url
                print(f"[OK] Connected and authenticated to Home Assistant at {url}")
                break
            else:
                await conn.close()
        except Exception:
            continue
            
    if not ws:
        raise ConnectionError("Failed to connect to any Home Assistant WebSocket endpoints.")
        
    try:
        # 1. Fetch Agents and current backup info
        req_id = 1
        await ws.send(json.dumps({"id": req_id, "type": "backup/agents/info"}))
        agents_resp = json.loads(await ws.recv())
        req_id += 1
        
        agent_ids = []
        if agents_resp.get("success"):
            agent_ids = [a["agent_id"] for a in agents_resp["result"].get("agents", [])]
        if not agent_ids:
            agent_ids = ["hassio.local"]
            
        print(f"[INFO] Discovered backup storage agents: {agent_ids}")
        
        # 2. Query initial backup list
        await ws.send(json.dumps({"id": req_id, "type": "backup/info"}))
        initial_info_resp = json.loads(await ws.recv())
        req_id += 1
        
        initial_backups = {}
        if initial_info_resp.get("success"):
            for b in initial_info_resp["result"].get("backups", []):
                initial_backups[b.get("backup_id")] = b
        print(f"[INFO] Current existing backups count: {len(initial_backups)}")

        # 3. Dispatch backup generation
        print(f"[STAGE] Dispatching native full backup '{backup_name}'...")
        payload = {
            "id": req_id,
            "type": "backup/generate",
            "name": backup_name,
            "agent_ids": agent_ids,
            "include_homeassistant": True,
            "include_database": True,
            "include_folders": ["ssl", "share", "media"]
        }
        await ws.send(json.dumps(payload))
        gen_resp = json.loads(await ws.recv())
        req_id += 1
        
        if not gen_resp.get("success"):
            print(f"[ERROR] Backup dispatch failed: {gen_resp.get('error')}")
            raise RuntimeError(f"Backup generation request rejected: {gen_resp.get('error')}")
            
        print(f"[OK] Backup generation accepted: {gen_resp.get('result')}")
        
        # 4. Monitor backup progress until completion
        start_time = time.time()
        completed_backup = None
        
        print("[STAGE] Monitoring backup progress...")
        while time.time() - start_time < timeout_seconds:
            await asyncio.sleep(6)
            await ws.send(json.dumps({"id": req_id, "type": "backup/info"}))
            poll_resp = json.loads(await ws.recv())
            req_id += 1
            
            if poll_resp.get("success"):
                res = poll_resp.get("result", {})
                state = res.get("state", "idle")
                last_event = res.get("last_action_event", {})
                print(f"  [POLL] Backup manager state: '{state}' | Last event stage: '{last_event.get('stage')}' | Elapsed: {int(time.time() - start_time)}s")
                
                # Check for new backup entry
                for b in res.get("backups", []):
                    bid = b.get("backup_id")
                    if b.get("name") == backup_name or bid not in initial_backups:
                        completed_backup = b
                        break
                            
                if state == "idle" and completed_backup is not None:
                    print(f"[SUCCESS] Backup creation completed! ID: {completed_backup.get('backup_id')}")
                    break
            else:
                print(f"  [WARN] Failed to poll backup info: {poll_resp.get('error')}")
                
        if not completed_backup:
            # Query one last time
            await ws.send(json.dumps({"id": req_id, "type": "backup/info"}))
            final_resp = json.loads(await ws.recv())
            for b in final_resp.get("result", {}).get("backups", []):
                if b.get("name") == backup_name:
                    completed_backup = b
                    break
                    
        if not completed_backup:
            raise TimeoutError(f"Backup generation timed out after {timeout_seconds}s without recording completion.")
            
        # 5. Output formal JSON receipt
        receipt = {
            "status": "SUCCESS",
            "backup_id": completed_backup.get("backup_id"),
            "name": completed_backup.get("name"),
            "date": completed_backup.get("date"),
            "homeassistant_version": completed_backup.get("homeassistant_version"),
            "database_included": completed_backup.get("database_included"),
            "folders": completed_backup.get("folders"),
            "addons_count": len(completed_backup.get("addons", [])),
            "agents": completed_backup.get("agents"),
            "target_subsystem": "HaSSD06",
            "endpoint_used": connected_url
        }
        
        print("\n=== FORMAL BACKUP RECEIPT ===")
        print(json.dumps(receipt, indent=2))
        return receipt
        
    finally:
        await ws.close()

if __name__ == "__main__":
    bname = sys.argv[1] if len(sys.argv) > 1 else "HaSSD06_pre_change_baseline_20260823"
    asyncio.run(run_backup(bname))
