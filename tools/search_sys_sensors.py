#!/usr/bin/env python3
"""
HaSSD06 System Sensors & Hardware Telemetry Inspector
Queries and formats all CPU, temperature, storage, fan, and network metrics.

Usage:
    python search_sys_sensors.py
    python search_sys_sensors.py --filter thermal
    python search_sys_sensors.py --json
"""

import argparse
import json
import sys
from mcp_ha_readonly import ha_api_get

# Ensure clean UTF-8 console output
sys.stdout.reconfigure(encoding="utf-8")

def parse_arguments():
    parser = argparse.ArgumentParser(description="Search and inspect system metrics on HaSSD06.")
    parser.add_argument(
        "--filter", "-f",
        default="",
        help="Optional search filter (e.g. 'cpu', 'temp', 'fan', 'disk', 'srat', 'network')."
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output raw JSON format instead of table."
    )
    return parser.parse_args()

def main():
    args = parse_arguments()
    print("=" * 70)
    print("HaSSD06 System Sensors & Hardware Telemetry Inspector")
    print("=" * 70)

    states = ha_api_get("states")
    if not isinstance(states, list):
        print("[-] Error fetching states from Home Assistant API.")
        if isinstance(states, dict) and "error" in states:
            print(f"[-] Details: {states['error']}")
        sys.exit(1)

    # Keywords for system/hardware telemetry
    keywords = [
        "system_monitor", "processor", "cpu", "memory", "disk",
        "temperature", "fan", "climate", "srat", "host", "rpi"
    ]
    # Exclusion list for room climate sensors unless requested
    exclusions = ["fp300", "sh_trv", "sbtr", "h5075", "echo", "dot_"]

    matched = []
    for s in states:
        eid = s.get("entity_id", "")
        fname = s.get("attributes", {}).get("friendly_name", "")
        
        # Apply filter if provided
        if args.filter:
            if args.filter.lower() in eid.lower() or args.filter.lower() in fname.lower():
                matched.append(s)
            continue
        
        # Default system search
        if any(k in eid.lower() or k in fname.lower() for k in keywords):
            if not any(k in eid.lower() for k in exclusions):
                matched.append(s)

    if args.json:
        print(json.dumps(matched, indent=2, ensure_ascii=False))
        return

    print(f"\nFound {len(matched)} matching system and hardware entities:\n")
    print(f"{'Entity ID':<48} | {'State':<15} | {'Unit':<8} | {'Friendly Name'}")
    print("-" * 105)

    for s in sorted(matched, key=lambda x: x.get("entity_id", "")):
        eid = s.get("entity_id", "")
        state_val = str(s.get("state", ""))
        unit = str(s.get("attributes", {}).get("unit_of_measurement", ""))
        fname = str(s.get("attributes", {}).get("friendly_name", ""))
        
        print(f"{eid:<48} | {state_val:<15} | {unit:<8} | {fname}")

    print("-" * 105)
    print(f"[+] Total inspected entities: {len(matched)}")
    print("[+] Done.\n")

if __name__ == "__main__":
    main()
