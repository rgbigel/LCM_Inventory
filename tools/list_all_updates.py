import json
import urllib.request
import sys

# Set output encoding to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

import os

secrets_path = r'D:\Git_Repositories\HaSSD06_Inventory\data\secrets.json'
if os.path.exists(secrets_path):
    with open(secrets_path, 'r', encoding='utf-8') as f:
        sec = json.load(f)
        token = sec.get('ha_auditor_token', '')
        url_states = sec.get('api_url', 'http://192.168.10.6:8123').rstrip('/') + '/api/states'
else:
    token = ''
    url_states = 'http://192.168.10.6:8123/api/states'

req_st = urllib.request.Request(url_states, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
with urllib.request.urlopen(req_st, timeout=10) as resp:
    states = json.loads(resp.read().decode('utf-8'))

update_entities = [s for s in states if s.get("entity_id", "").startswith("update.")]
print(f"=== ALL {len(update_entities)} UPDATE / ADDON / HACS TRACKING ENTITIES ===")
for u in update_entities:
    installed = u.get("attributes", {}).get("installed_version")
    latest = u.get("attributes", {}).get("latest_version")
    title = u.get("attributes", {}).get("title") or u.get("attributes", {}).get("friendly_name")
    print(f"  - {u['entity_id']:<45} | '{title}' | Installed: {installed} | Latest: {latest}")

