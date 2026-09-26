# Implementation Plan: BUG-179

```yaml
BUG-ID: BUG-179
Title: Tool Explorer Alias Omission, Subsystem Override Reversion, and Two-State Finalize Blockade Defect
Scope: .lcm, Workspace_Inventory, Tool Explorer UI, Tool Catalog Sync Engine, LCM Desktop Daemon
Status: Completed
Date: 2026-09-26
```

---

## 1. Objectives
1. Restore `BCR` launcher and alias pill display for `Invoke-BeyondCompareReview.ps1`.
2. Fix `masterIdx` derivation in `lcm-tool-explorer.js` to disambiguate tools sharing identical filenames.
3. Ensure `finalizeTool` and `revertTool` clear in-memory and local storage blockade state completely.
4. Support `Group` / `Domain` / `Subsystem` persistence in `DaemonActionController.ps1` and `Update-ToolCatalog.ps1`.

---

## 2. Execution Steps

### Phase 1: Tool Catalog Metadata & Trampoline Generation
- [x] Add `Aliases = @("BCR")` to `"Invoke-BeyondCompareReview.ps1"` in `Update-ToolCatalog.ps1`.
- [x] Allow `$meta.Group` / `$meta.Subsystem` to override `$sd.Group` in catalog entries.
- [x] Execute `Update-ToolCatalog.ps1` to produce `BCR.cmd` in `.lcm/Cmd/`.

### Phase 2: Tool Explorer UI Ergonomics & Blockade Cleanup
- [x] Update `renderTable` in `lcm-tool-explorer.js` to key master index by `RelativePath`.
- [x] Display alias pills in default Short-Names mode when alternative short names exist.
- [x] Harden `saveCellEdit`, `markToolPending`, `revertTool`, and `finalizeTool` to clear pending flags and unblock tools cleanly.
- [x] Mirror `lcm-tool-explorer.js` between `Workspace_Inventory/assets/` and `.lcm/assets/`.

### Phase 3: Daemon State Synchronization
- [x] Update `DaemonActionController.SyncCatalogState` to update `Group`, `Domain`, and `Subsystem` fields.
- [x] Persist dynamic overrides to `.lcm/config/tool_catalog_overrides.json`.

### Phase 4: Validation & Registration
- [x] Validate daemon `/query_all_short_names` endpoint.
- [x] Verify `Show-ToolsExplorer.ps1 -NoLaunch` dashboard compilation.
- [x] Register `BUG-179` in `proposals.json`.
- [x] Complete commit across `Workspace_Inventory` and root `.lcm`.
