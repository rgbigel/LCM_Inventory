# Implementation Plan: CRP-177

```yaml
CRP-ID: CRP-177
Title: Tool Explorer Ergonomics, Daemon Log Truncation, and Automated Workspace Maintenance Engine
Gate: Gate 2 (Visual Review & Disposition Gate)
Status: completed
Priority: Medium
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
```

---

## Planned Execution Steps

### Phase 1: Tool Explorer Ergonomics & Disambiguation
1. Update `.lcm/tools/internal/Update-ToolCatalog.ps1`:
   - Add explicit disambiguation mapping for `HaSSD06_Inventory\Test-RepoReadiness.ps1` &rarr; `TestHaRepoReady`.
   - Purge stale `HaSSD06InventoryTestRepoReadiness.cmd` and generate `TestHaRepoReady.cmd`.
2. Update `.lcm/modules/LcmToolCatalog.psm1`:
   - Remove `card-noexit` metric card button.
   - Insert `#` index column header (`<th>#</th>`) with `window.LcmTools.sortTable('Index')`.
   - Update column filter dropdown label from "All Groups" to "All Subsystems".
   - Compact header utility buttons (`Refresh`, `Export`, `Theme`, `Help`, `Back`).
3. Update `LCMToolCatalog.css` in both `.lcm/assets` and `Workspace_Inventory/assets`:
   - Compact `.btn-action` and `.btn-menu-trigger` padding and font size.
   - Adjust table layout for the `#` index column.
4. Update `lcm-tool-explorer.js` in both `.lcm/assets` and `Workspace_Inventory/assets`:
   - Strip pictograms (`📁 `, `💬 `) from tool name display.
   - Insert formatted `#` cell with `001-max` sequence number tied to unfiltered index.
   - Implement in-place cell editing for `Group` (Subsystem) with dynamic options including `"Needed?"`.
   - Add `Index` sorting branch in `applyFilters`.

### Phase 2: Workspace Maintenance & Daemon Log Truncation Engine
1. Author canonical script `Workspace_Inventory/tools/Invoke-WorkspaceMaintenance.ps1`:
   - Implement `Invoke-DaemonLogTruncation` with line tailing (~100 lines) and retry guard against transient file locks.
   - Implement log aging (`-MaxLogAgeDays 7`) and transient script log purging (`-MaxScriptLogAgeDays 3`).
   - Wire `Clear-BCReviewTemp.ps1` for review scratch older than 48 hours.
   - Implement scratch temporary junk pruning (`*.tmp`, `*~`).
2. Author wrapper `.lcm/tools/internal/Invoke-WorkspaceMaintenance.ps1`.
3. Create launcher `.lcm/Cmd/WorkspaceMaintenance.cmd`.
### 2.5 Per-CRP Review Directory Isolation & Session Naming
1. Update `Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1`:
   - Resolve `$CRP` before path calculation.
   - Route review scratch to dedicated subfolder: `scratch\BC_Review\<CRP>\Baseline_<Repo>_<SHA>\` and `Live_<Repo>\`.
   - Update `BCSessions.xml` with dedicated named session `<CRP>_Review` and mirror `LCM_Review`.
2. Update `Workspace_Inventory/tools/Clear-BCReviewTemp.ps1`:
   - Add safe child junction unlinking before recursive directory removal.

### Phase 3: Verification & Validation
1. Execute `Invoke-WorkspaceMaintenance.ps1` live:
   - Verify active daemon logs truncated to 100 lines and report storage freed.
2. Execute `Show-Tools.ps1 -Audience All -NoLaunch` and verify HTML generation.
3. Execute `Invoke-WorkspacePush.ps1 -DryRun` to validate pre-push pipeline end-to-end.
