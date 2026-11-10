---
Proposal-ID: CRP-145
Scope: HaSSD06_Inventory
Version: 10.2.0
Affected-Repos: [HaSSD06_Inventory]
Priority: High
Status: Open
Target Scope: Subsystem Explorer Devices Page
---

# CRP-145: Dedicated Devices Explorer Page with Dropdown Selection, Two-Way Entity Linking, and Label Column

## 1. Problem Statement & Motivation
A dedicated, first-class **Devices Explorer** page/tab is required to inspect all registered physical hardware and virtual integration nodes. Operators must be able to select and filter devices via dropdowns, navigate seamlessly between Devices and their associated Entities via two-way clickable links, and inspect device labels, areas, manufacturers, models, and integration bindings.

## 2. Proposed Enhancements
1. **Dedicated Devices Table / View**:
   - Provide a primary `Devices` tab in the Subsystem Inventory Explorer.
   - Include columns: `Device Name`, `Manufacturer / Model`, `Area / Room`, `Labels / Tags`, `Integration / Binding`, `Entity Count`, and `Actions`.
2. **Device Dropdown Selector & Quick Filter**:
   - Add a device selector dropdown in the toolbar and column header to quickly jump to or isolate a specific device.
3. **Two-Way Clickable Linking**:
   - Clicking a device in the Devices view opens its child entities or filters the Live Entities view to that device.
   - Clicking a device badge in the Live Entities view switches to and highlights the device in the Devices view.
4. **Dedicated Label Column**:
   - Display assigned labels, tags, and category metadata for each device.
5. **Standard Display Compliance**:
   - Conforms to `StandardTableDisplay.css`, double-row sticky headers, and dark/light theme switching.

## 3. Impacted Assets
- [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)
- [`HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html)
- [`HaSSD06_Inventory/data/subsystem_inventory.json`](file:///d:/Git_Repositories/HaSSD06_Inventory/data/subsystem_inventory.json)
