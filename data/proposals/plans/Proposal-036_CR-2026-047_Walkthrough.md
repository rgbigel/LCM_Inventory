# Walkthrough - Proposal #36 (CRP-2026-014): Disable Raspberry Pi Bluetooth Adapter & Consolidate BLE to Shelly Gateway

We have completed the deactivation of the Raspberry Pi onboard Bluetooth adapter (`01KM0AR8WX9XT1S9AFJ92TP3JP` / `bcm43438-bt`), successfully consolidating all Bluetooth Low Energy (BLE) ingestion to the centrally located **`shellyblugwg3` Shelly BLU Gateway G3** proxy (`01KB11EY1Y2WCQWT3RW058AH38`).

---

## 1. Accomplishments & Execution

### 📡 Single-Gateway Consolidation
* **Onboard Adapter Deactivated**: Sent `config_entries/disable` payload via WebSocket to Home Assistant for entry `01KM0AR8WX9XT1S9AFJ92TP3JP` (`Raspberry Pi Trading Ltd bcm43438-bt`).
* **Zero Disruption / Instant Handover**: Disabled without requiring a host reboot (`require_restart: false`).
* **Zero Orphan Devices**: Verified that all registered BLE devices (3x Shelly BLU TRV climate thermostats, Govee H5075 thermo-hygrometer, and BTHome environmental probes) communicate exclusively through `shellyblugwg3` with strong signal margins (`-57 dBm` to `-60 dBm`).

---

## 2. Verification & Health Results

### 🧪 Entity Live State Verification
Executed `HaSSD06/scratch/check_bt_entities.py`:
* **Total Active Bluetooth Entities**: **33/33 Online**
  * `climate.sh_trv_sz` (Bedroom TRV): `state=heat`, `RSSI=-60 dBm`
  * `climate.sh_trv_bad` (Bathroom TRV): `state=heat`, `RSSI=-57 dBm`
  * `climate.sh_trv_wz` (Living Room TRV): `state=heat`, `RSSI=-59 dBm`
  * `sensor.h5075_bc98_temperature` (Govee T/H SZ): `state=24.6°C`
  * `sensor.h5075_bc98_humidity` (Govee T/H SZ): `state=52.1%`
  * `sensor.t_h_bath_*` & `sensor.t_h_terrasse_*`: `Online / Active`

### 📊 Subsystem Telemetry
* Executed [`HaSSD06_Inventory/tools/Update-HaInventory.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Update-HaInventory.ps1).
* Generated updated [`SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html) and [`SUBSYSTEM_DASHBOARD.md`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SUBSYSTEM_DASHBOARD.md).
