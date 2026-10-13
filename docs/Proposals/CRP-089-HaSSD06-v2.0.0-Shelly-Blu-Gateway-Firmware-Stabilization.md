---
Proposal-ID: CRP-089
CR-ID: CR-2026-040
Scope: HaSSD06
Version: 10.0.0
Affected-Repos: [HaSSD06, HaSSD06_Inventory]
Status: Suggested
Date: 2026-10-13
Author: rgbig
Target Scope: HaSSD06 / devices / shellyblugwg3
Affected Version Range: 10.0.0-beta1 -> 10.0.0
Impacted Repositories: [HaSSD06, HaSSD06_Inventory]
---

# CRP-089: Shelly BLU Gateway Firmware Stabilization (10.0.0-beta1 -> 10.0.0 Stable)

## 1. Executive Summary & Intent
Transition device `shellyblugwg3-b08184e55650` (`update.shellyblugwg3_b08184e55650_firmware`) from pre-release beta firmware `10.0.0-beta1` to production stable firmware `10.0.0`.

## 2. Release Notes & Technical Impact
* **Target Version**: `10.0.0` (Official Stable Release)
* **Release Changelog**: https://shelly-api-docs.shelly.cloud/gen2/changelog/
* **Impact**: Eliminates Bluetooth gateway telemetry jitter and stabilizes BTHome passive sensor broadcasts.

## 3. Execution Plan
1. Trigger device firmware flash via `update.install` service.
2. Confirm device re-registers with Shelly integration.
3. Refresh `data/subsystem_inventory.json` via `Update-HaInventory.ps1`.

