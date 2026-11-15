import json
import urllib.request
import sys

# Ensure UTF-8 output on Windows
sys.stdout.reconfigure(encoding="utf-8")

with open('d:/Git_Repositories/HaSSD06/.ha_token', 'r', encoding='utf-8') as f:
    token = f.read().strip()

url = 'http://192.168.10.6:8123/api/config'
req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
with urllib.request.urlopen(req, timeout=10) as resp:
    config = json.loads(resp.read().decode('utf-8'))

url_states = 'http://192.168.10.6:8123/api/states'
req_st = urllib.request.Request(url_states, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
with urllib.request.urlopen(req_st, timeout=10) as resp:
    states = json.loads(resp.read().decode('utf-8'))

print(f"HA Version: {config.get('version')}")
print(f"Config Dir: {config.get('config_dir')}")

# Identify all custom components
custom_components = []
for c in config.get("components", []):
    # Custom components often have specific signatures or known HACS names
    if any(k in c for k in ["hacs", "tuya_local", "localtuya", "eufy_security", "alexa_media", "browser_mod", "card_mod", "mushroom", "auto_entities", "sonoff", "smartir"]):
        custom_components.append(c)

print(f"\nDiscovered Custom / HACS Components Loaded ({len(custom_components)}):")
for c in sorted(custom_components):
    print(f"  - {c}")

# Find all template entities
template_entities = [s for s in states if "template" in s.get("entity_id", "") or "template" in s.get("attributes", {}).get("friendly_name", "").lower()]
print(f"\nDiscovered Template Entities ({len(template_entities)}):")
for t in template_entities:
    print(f"  - {t['entity_id']}: '{t.get('attributes', {}).get('friendly_name')}' (State: {t.get('state')})")

# Find update entities (HACS updates, Core updates, OS updates, Zigbee updates)
update_entities = [s for s in states if s.get("entity_id", "").startswith("update.")]
print(f"\nDiscovered Update Entities ({len(update_entities)}):")
for u in update_entities:
    installed = u.get("attributes", {}).get("installed_version")
    latest = u.get("attributes", {}).get("latest_version")
    print(f"  - {u['entity_id']}: '{u.get('attributes', {}).get('friendly_name')}' [Installed: {installed} -> Latest: {latest}]")

