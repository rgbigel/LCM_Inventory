---
Proposal-ID: CRP-114
CR-ID: CRP-114
Scope: LCM / Tool Explorer & Dashboard UI
Version: v7.3.0
Affected-Repos: [LCM]
Status: OPEN
Date: 2026-09-07
Author: rgbig
Target Scope: LCM_Inventory/modules/LcmToolCatalog.psm1, LCM_Inventory/tools/Show-Tools.ps1, LCM_Inventory/assets/lcm-tool-explorer.js, SHOW_TOOLS.html
Affected Version Range: v7.3.0
Impacted Repositories: [LCM]
Severity: Low
---

# CRP-114 / CRP-114: Remove Deprecated HaSSD06 Subsystem Filter Button from Tool Explorer

## 1. Proposal Summary & Rationale
In the LCM Tool Explorer dashboard (`SHOW_TOOLS.html` / `Show-Tools.ps1`), a dedicated quick-filter button for the `HaSSD06` subsystem was historically placed in the primary filter bar. As the LCM workspace has evolved to encompass many additional subsystems (e.g. `SystemConfiguration`, `VolumeInventory`, `LCM_Inventory`, `BootEntryManager`, etc.), hardcoding a dedicated button for one specific subsystem is obsolete and redundant with the dynamic Group / Subsystem dropdown filter.

## 2. Proposed Changes
1. **Remove Hardcoded HaSSD06 Button**:
   - In `LcmToolCatalog.psm1` (and generated templates in `SHOW_TOOLS.html` / `lcm-tool-explorer.js`), remove the dedicated `<button class="tab-btn" data-group="HaSSD06">🏠 HaSSD06</button>` button.
2. **Clean Up Show-Tools CLI Parameters**:
   - Deprecate or retire `-HaSSD06` switch parameter in `Show-Tools.ps1` in favor of `-Group HaSSD06` or `-Subsystem HaSSD06`.
3. **Dynamic Subsystem Filtering**:
   - Rely exclusively on the unified dynamic Group / Subsystem column dropdown filter and global search engine.
4. **Verification**:
   - Regenerate Tool Explorer HTML via `Show-Tools.ps1 -NoLaunch` and verify the UI layout.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this change request proposal is registered in the `OPEN` state. Implementation planning and code edits will commence upon receipt of an explicit `PROCEED 114` or `PROCEED ALL` command.

