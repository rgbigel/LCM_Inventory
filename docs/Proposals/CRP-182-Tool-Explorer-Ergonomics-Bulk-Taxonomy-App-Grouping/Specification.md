# CRP-182: Tool Explorer Audience Segmentation, Alias Management, Bulk Taxonomy Renaming, Dynamic Sequence Numbering, and App Grouping Alignment

* **Proposal ID**: CRP-182
* **Target Scope**: `.lcm/assets/lcm-tool-explorer.js`, `.lcm/tools/internal/Show-ToolsExplorer.ps1`, `LCM_Inventory`
* **Author**: Rolf, LCM_AI Engine
* **Date**: 2026-09-27
* **Status**: In-Review / Gated

---

## 1. Executive Summary & Intent
This change request addresses 9 specific ergonomic, structural, and versioning enhancements in the authoritative LCM Tool Explorer:
1. **Audience "Internal" Segmentation (`Int.` button)**: Add a toggle button `Int.` immediately to the right of `ShowTools` to switch the visibility of internal/diagnostic tools (`Audience: "Internal"` or `"Admin"`).
2. **ShowTools Default Filter State**: Default `ShowTools` to **ON** when opening a new Tool Explorer window (without altering state on page refresh). Set initial pristine filter on first activation to: `Audience = 'User'`, `Group = 'LCM'`, no other filters, sorted by `ShortName` ascending.
3. **Granular Alias Management**: Replace the crude "delete all" button in the rename modal with interactive alias management: list existing aliases, add individual aliases, and delete specific aliases via interactive pill tags.
4. **Generalized Bulk Taxonomy Renaming**: Enable mass-rename / assignment for all dropdown-based columns (e.g. `Group`, `Category`) across currently visible/filtered tools (e.g. bulk rename `Workspace*` $\rightarrow$ `LCD`, `System Customization` $\rightarrow$ `PC Cust.`).
5. **Taxonomy Evolution: `Subsys` $\rightarrow$ `Group`**: Rebrand the UI column `Subsys` to `Group` (with App-centric mapping support, e.g. `HaSSD06_App#A1`), aligning UI display with the underlying catalog schema and LCM App-centric architecture (`RULE-DOC-007`).
6. **Version Parity Auto-Sync**: Elevate Tool Explorer version from `v7.5.0` to `v8.0.0` and auto-bind to the workspace baseline.
7. **Post-Sort Sequence Numbering (`#`)**: Calculate and display dynamic sequence numbers (1, 2, 3...) strictly after active sorting/filtering rather than historical catalog indices.
8. **ShortName Column Sizing & Stacked Aliases**: Reduce the width of the `ToolName` column in ShortName view and render aliases on clean, separate lines.
9. **Documentation & Help Synchronization**: Update all relevant documentation, command manuals, and in-app help modals.
