# Implementation Plan - Proposal #36 (CRP-2026-014): Disable Raspberry Pi Onboard Bluetooth Adapter & Consolidate BLE to Shelly Gateway

## User Review Required
> [!NOTE]
> **Zero-Orphan Hardware Audit Passed**: We conducted an exhaustive registry and entity audit of all physical Bluetooth devices on `HaSSD06`. 
> 100% of all registered BLE devices (Govee H5075 thermo-hygrometer and the 3 Shelly BLU TRV climate thermostats in Bedroom, Bathroom, Living Room) have direct, strong radio link margins (`-59 dBm` to `-60 dBm`) with the **`shellyblugwg3` Shelly BLU Gateway G3**. Zero devices communicate exclusively with the Raspberry Pi.

---

## Proposed Changes

### Subsystem Configuration (`HaSSD06`)

#### [MODIFY] [Bluetooth Integration Config Entry](file:///d:/Git_Repositories/HaSSD06)
* Deactivate the onboard Broadcom Bluetooth adapter entry (`01KM0AR8WX9XT1S9AFJ92TP3JP` / `bcm43438-bt` / `D8:3A:DD:16:D4:F7`) via Home Assistant WebSocket API.
* All BLE device advertisement parsing and telemetry ingestion will route exclusively through `01KB11EY1Y2WCQWT3RW058AH38` (`shellyblugwg3-b08184e55650`).

### Subsystem Inventory & Ledgers (`HaSSD06_Inventory`)

#### [MODIFY] [data/subsystem_inventory.json](file:///d:/Git_Repositories/HaSSD06_Inventory/data/subsystem_inventory.json) & [docs/SUBSYSTEM_DASHBOARD.md](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SUBSYSTEM_DASHBOARD.md)
* Refresh telemetry ledgers via `Update-HaInventory.ps1` to reflect the updated single-gateway Bluetooth topology.

---

## Verification Plan

### Automated Tests
1. **Execute Deactivation**:
   ```powershell
   python HaSSD06/scratch/disable_pi_bt.py
   ```
2. **Verify All 33 Bluetooth Entities Remain Online**:
   ```powershell
   python HaSSD06/scratch/check_bt_entities.py
   ```
3. **Flapping & State Jitter Verification**:
   ```powershell
   python HaSSD06/scratch/analyze_flapping_entities.py
   ```
   * Confirm that unavailable dropouts and micro-oscillations in `sensor.h5075_bc98_*` drop to zero.
4. **Telemetry Refresh**:
   ```powershell
   pwsh -File HaSSD06_Inventory/tools/Update-HaInventory.ps1
   ```

### Manual Verification
* Inspect Home Assistant UI under *Settings -> Devices & Services -> Bluetooth* to verify that `shellyblugwg3` is the active Bluetooth scanner.
