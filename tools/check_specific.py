#!/usr/bin/env python3
"""
HaSSD06 Specific Entity State & Attribute Inspector
Allows querying any specific entity ID or list of entities with full attribute inspection.

Usage:
    python check_specific.py
    python check_specific.py --entity light.leuchter
    python check_specific.py --search buro
"""

import argparse
import sys
from mcp_ha_readonly import ha_api_get

# Ensure clean UTF-8 console output
sys.stdout.reconfigure(encoding="utf-8")

DEFAULT_SUSPECT_ENTITIES = [
    "light.leuchter",
    "light.tuya3_buro",
    "switch.buro_2",
    "sensor.leselampe_power",
    "switch.leselampe",
    "climate.rpi_cooling_fan_controller",
    "sensor.srat_global_disk_health"
]

def parse_arguments():
    parser = argparse.ArgumentParser(description="Inspect specific entities on HaSSD06.")
    parser.add_argument("--entity", "-e", help="Exact entity_id to inspect.")
    parser.add_argument("--search", "-s", help="Search keyword across all entities.")
    return parser.parse_args()

def inspect_entity(entity_id: str):
    data = ha_api_get(f"states/{entity_id}")
    if isinstance(data, dict) and "error" in data:
        print(f"[-] {entity_id}: {data['error']}")
        return
    print(f"\n{'=' * 60}")
    print(f"ENTITY: {entity_id}")
    print(f"{'=' * 60}")
    print(f"State:        {data.get('state')}")
    print(f"Friendly Name:{data.get('attributes', {}).get('friendly_name', 'N/A')}")
    print(f"Last Changed: {data.get('last_changed', 'N/A')}")
    print(f"Last Updated: {data.get('last_updated', 'N/A')}")
    print("Attributes:")
    for k, v in sorted(data.get("attributes", {}).items()):
        print(f"  - {k:<30}: {v}")

def search_entities(keyword: str):
    states = ha_api_get("states")
    if not isinstance(states, list):
        print("[-] Failed to retrieve states.")
        return
    matches = [s for s in states if keyword.lower() in s.get("entity_id", "").lower() or keyword.lower() in s.get("attributes", {}).get("friendly_name", "").lower()]
    print(f"\n[+] Found {len(matches)} matches for '{keyword}':")
    for m in matches:
        print(f"  - {m['entity_id']:<45} | State: {m.get('state')} | Name: '{m.get('attributes', {}).get('friendly_name')}'")

def main():
    args = parse_arguments()
    
    if args.entity:
        inspect_entity(args.entity)
    elif args.search:
        search_entities(args.search)
    else:
        print("=" * 60)
        print("HaSSD06 Default Suspect Entity Inspection")
        print("=" * 60)
        for eid in DEFAULT_SUSPECT_ENTITIES:
            inspect_entity(eid)
        print(f"\n[+] Inspected {len(DEFAULT_SUSPECT_ENTITIES)} default suspect entities.")
        print("[+] Tip: Use `python check_specific.py --entity <entity_id>` or `--search <keyword>`.")

if __name__ == "__main__":
    main()
