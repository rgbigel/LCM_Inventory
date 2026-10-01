# Implementation Plan: Configuration Management (CM) Control Hub & Batch Review Engine

**Proposal ID**: #19  
**Change Request**: `CR-2026-030`  
**Bundle ID**: `CRP-2026-006`  
**Scope**: `LCM_Inventory / tools`  
**Date**: 2026-08-30  

## Proposed Changes
1. Author `LCM_Inventory/docs/CM_CONTROL_HUB.html` Single-Page Web Dashboard:
   - Real-time ledger binding to `proposals.json`.
   - Dual-state & `bug` status selectors.
   - Default Show All & All Repos view with sticky subsystem filter.
   - Batch selection, Beyond Compare launcher, and batch Accept All.
   - Modal drawer for Plans, Walkthroughs, CRP specs, and JSON Review Receipts.
   - Notepad++ launcher with review auto-sync and bypass switch.
   - Integrated log viewer for `cm_activity.log` and `logs/history/`.
2. Author `LCM_Inventory/tools/Show-CmControlHub.ps1`.
3. Create short-name trampolines:
   - `.lcd/Cmd/CmHub.cmd`
   - `.lcd/Cmd/DOR.cmd`
   - `.lcd/Cmd/DoReview.cmd`
4. Register tools in `.lcd/config/tool_catalog.json` via `Update-ToolCatalog.ps1`.
5. Verify in browser and execute quality gates.
