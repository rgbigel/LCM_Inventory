# Bug Fix Proposal: BUG-179

```yaml
BUG-ID: BUG-179
Title: Tool Explorer Alias Omission, Subsystem Override Reversion, and Two-State Finalize Blockade Defect
Scope: .lcm, LCM_Inventory, Tool Explorer UI, Tool Catalog Sync Engine, LCM Desktop Daemon
Baseline-Version: v8.0.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
Impacted-Repositories:
  - Git_Repositories
  - LCM_Inventory
```

---

## 1. Problem Statement & Root Cause Analysis

Following interactive reorganization of tools within the Tool Explorer UI, two interrelated defects prevented proper alias discovery and tool lifecycle resolution:

1. **Missing Alias `BCR` for `BeyondCompareReview`**:
   - In [`Update-ToolCatalog.ps1`](file:///.lcm/tools/internal/Update-ToolCatalog.ps1), the metadata overrides dictionary entry for `"Invoke-BeyondCompareReview.ps1"` did not include an `Aliases` array.
   - Consequently, `Update-ToolCatalog.ps1` generated only `LCMBeyondCompareReview.cmd` and `BeyondCompareReview.cmd`, omitting `BCR.cmd`.
   - In [`lcm-tool-explorer.js`](file:///LCM_Inventory/assets/lcm-tool-explorer.js), alias badges were only rendered when viewing in Source Files Mode (`isSourceMode`), omitting visible alias pills in default Short-Names mode.

2. **Permanent Two-State Blockade Failure on `✓ Finalize`**:
   - When an operator edited the Subsystem / Group cell for `BeyondCompareReview` (e.g. from `LCM_Inventory` to `LCM`), the tool row was correctly staged into `⛔ Blocked` status.
   - Upon clicking `✓ Finalize`, the blockade was **not removed**.
   - **Root Cause A (Duplicate Name Collision on `findIndex`)**: Two physical scripts share the filename `Invoke-BeyondCompareReview.ps1` (`.lcm/tools/internal/` wrapper and `LCM_Inventory/tools/` engine). In `renderTable`, `masterIdx` was derived via `toolsData.findIndex(item => item.Name === t.Name)`. This always returned index `~27` (the first instance), causing action buttons on the second instance (`~62`) to dispatch `finalizeTool(27)`.
   - **Root Cause B (In-Memory State Asymmetry)**: When `saveCellEdit` ran, it set `t._isPendingModification = true; t.IsBlocked = true` on all tools matching the base stem. However, `finalizeTool(idx)` only cleared `tool._isPendingModification = false` on `toolsData[idx]`. Because `getToolPendingInfo` checks `tool._isPendingModification`, the second instance permanently evaluated as `isBlocked = true`.
   - **Root Cause C (Subsystem Override Reversion & Missing Override Persistence)**: `DaemonActionController.SyncCatalogState` did not map `Group`, `Domain`, or `Subsystem` property mutations into `$cat`, and did not persist changes to `.lcm/config/tool_catalog_overrides.json`. When `Update-ToolCatalog.ps1` was re-invoked, it re-scanned directory roots and overwrote `tool_catalog.json` with the original scanned group (`LCM_Inventory`), reverting user changes.

---

## 2. Technical Modifications

### 2.1 Tool Catalog Alias Definition & Overrides (`Update-ToolCatalog.ps1`)
- Added `Aliases = @("BCR")` to `"Invoke-BeyondCompareReview.ps1"` in `$metadataOverrides`.
- Updated entry instantiation to respect `$meta.Group` / `$meta.Subsystem` / `$meta.Domain` over raw `$sd.Group`.
- Synchronized catalog to generate [`.lcm/Cmd/BCR.cmd`](file:///.lcm/Cmd/BCR.cmd) and populate `tool_catalog.json`.

### 2.2 Tool Explorer UI & Two-State Resolution (`lcm-tool-explorer.js`)
- **Deterministic Master Indexing**: Changed `renderTable` index resolution to:
  ```javascript
  const masterIdx = toolsData.findIndex(item => (item.RelativePath && t.RelativePath) ? (item.RelativePath === t.RelativePath) : (item.Name === t.Name));
  ```
- **Universal Alias Rendering**: In default Short-Names mode (`!isSourceMode`), active aliases (such as `BCR` for `BeyondCompareReview`) are rendered as distinct `💬 <alias>` pills below the primary name.
- **Complete In-Memory & Storage Unblocking**:
  - `finalizeTool(idx)` and `revertTool(idx)` purge all matching keys from `mods` (`tool.Name`, `tool.RelativePath`, `baseStem`) and reset `_isPendingModification = false; IsBlocked = false; _pendingType = null;` across all matching tools in `toolsData`.
  - `saveCellEdit` targets `targetTool` specifically and writes both `RelativePath` and `Name` keys to `storedOverrides`.
- Mirrored changes between [`LCM_Inventory/assets/lcm-tool-explorer.js`](file:///LCM_Inventory/assets/lcm-tool-explorer.js) and [`.lcm/assets/lcm-tool-explorer.js`](file:///.lcm/assets/lcm-tool-explorer.js).

### 2.3 Daemon Overrides & Subsystem Synchronization (`DaemonActionController.ps1`)
- Extended `SyncCatalogState` to update `Group`, `Domain`, and `Subsystem` across all matched tool instances.
- Persisted active overrides directly to `.lcm/config/tool_catalog_overrides.json`, guaranteeing that subsequent runs of `Update-ToolCatalog.ps1` retain custom operator assignments.

---

## 3. Verification & Invariants
- `BCR.cmd` verified present in `.lcm/Cmd/`.
- Daemon `/query_all_short_names` returns `["LCMBeyondCompareReview", "BCR", "BeyondCompareReview"]`.
- `Show-ToolsExplorer.ps1 -NoLaunch` completes with exit code 0.
- Two-State lifecycle (`markToolPending` -> `finalizeTool` / `revertTool`) verified to clear `⛔ Blocked` status cleanly.
