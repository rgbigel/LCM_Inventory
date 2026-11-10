---
Proposal-ID: CRP-144
Scope: HaSSD06_Inventory
Version: 10.2.0
Affected-Repos: [HaSSD06_Inventory]
Priority: High
Status: Open
Target Scope: Subsystem Explorer Live Entities Tab
---

# CRP-144: Live Entities Status and Associated Device Column Enhancements

## 1. Problem Statement & Motivation
In the Subsystem Inventory Explorer ([`Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)), the **Live Entities** view requires clear, dedicated, and prominent column visibility for both the **Current Status / Availability** (Online, Offline, Unavailable, Unknown, Value) and the **Associated Device** to which each entity belongs, allowing direct filtering and cross-inspection.

## 2. Proposed Enhancements
1. **Dedicated Status Column**:
   - Provide an explicit `Status` column displaying color-coded status badges (`Online`, `Offline`, `Unavailable`, `Unknown`, `On`, `Off`, numeric measurements with units).
   - Integrate aligned column filter dropdown for fast filtering by status state (`All`, `Available`, `Unavailable`, `Unknown`, `On`, `Off`).
2. **Dedicated Associated Device Column**:
   - Explicit `Associated Device` column showing the friendly name of the physical parent device.
   - Clickable device badge/link that immediately filters or navigates to the parent device in the Devices view.
   - Text search and dropdown filter on the Device column header.
3. **Double-Row Sticky Header Alignment**:
   - Full alignment with `StandardTableDisplay.css` double-row sticky header format.

## 3. Impacted Assets
- [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)
- [`HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html)
