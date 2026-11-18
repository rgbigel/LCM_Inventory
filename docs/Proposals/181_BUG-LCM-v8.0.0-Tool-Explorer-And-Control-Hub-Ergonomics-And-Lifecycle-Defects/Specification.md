# Specification: BUG-181 Tool Explorer and Control Hub Ergonomics, Window Collision Isolation, Short-Name Renaming, and Lifecycle Defect Remediation

## 1. Overview & Problem Statement
During intensive operation of the LCM Configuration Management interface (Tool Explorer, Control Hub, and Sidecar), eight interrelated ergonomics, lifecycle state tracking, window management, and data persistence defects were identified:

1. **Bug 1 (Reset Button Styling)**: In dark mode, the Reset button had an unstyled/white background with poor contrast instead of a dark `#0d1117` background with prominent red text (`#f85149`).
2. **Bug 2 & 8 (Window Collision on Launch)**: Invoking `Show-ToolsExplorer` when `Show-LcmControl` was already open caused Zen Browser (Firefox-based) to overwrite the existing two-tab Control Hub/Sidecar window due to default single-window tab hijacking.
3. **Bug 3 (Short-Name & Launcher Persistence)**: Renaming `Show-LcmControl` ShortName to `ShowCM` failed to persist across catalog updates, lacked a backend `/rename` daemon REST endpoint, and accumulated unwanted trampoline aliases (`ShowCMControlHub.cmd`, `ShowHub.cmd`, `ShowCrpDates.cmd`). The user required exactly 0 aliases and clean canonical `ShowCM.cmd` invocation.
4. **Bug 4 (Subsystem Workspace* to LCM Overrides Persistence)**: In Tool Explorer, modifying the SubSystem of `Workspace*` tools to `LCM` and clicking `SetAll` produced a successful client toast, but refreshing the page reverted the edits because `Update-ToolCatalog.ps1` resolved `$metadataOverrides` solely by base stem/leaf name rather than relative file path keys.
5. **Bug 5 (Sidecar Open Proposal Selection)**: When launching Control Hub with no active in-progress CRPs, Sidecar defaulted to proposal `122` because its filter only checked `state !== 'completed' && state !== 'pushed'`, admitting `rejected` and `deferred` proposals into the open candidates list.
6. **Bug 6 (Sidecar Proposal Selector Prominence)**: The proposal dropdown in the Sidecar header was a diminutive single-line input. It required expansion into a prominent two-line control styled with the vibrant green coloring of the `Complete` button (`var(--accent-green)` with `#738a00` border).
7. **Bug 7 (Sidecar Plan State & Status Selectors)**: The Sidecar displayed static text pills for Plan State and Status. It required top-line interactive dropdown selectors matching Control Hub with live daemon execution capabilities (`Invoke-ProposalAction.ps1 -Action state / progress`).
8. **Scrollbar Standardization**: Enforce permanent, visible 12px horizontal and vertical scrollbars with `overflow-x: scroll !important` across `LCM_SIDECAR.html`, `CM_CONTROL_HUB.html`, and `StandardTableDisplay.css`.

---

## 2. Technical Architecture & Component Changes

### 2.1 Tool Explorer Dark Mode Reset Button (`LCMToolCatalog.css`, `lcm-tool-explorer.js`, `LcmToolCatalog.psm1`)
- Added explicit dark-mode CSS classes: `.btn-reset`, `.btn-revert`, `.col-filter-reset-btn`:
  ```css
  background: #0d1117 !important;
  color: #f85149 !important;
  border: 1px solid rgba(248, 81, 73, 0.4) !important;
  ```
- Aligned filter row and per-row `Reset` button styles with the dark red scheme.

### 2.2 Independent Zen Browser Window Dispatch (`Show-LcmControl.ps1`, `Show-ToolsExplorer.ps1`)
- Updated Zen / Firefox launch semantics in `Show-LcmControl.ps1` to pass `--new-window "$launchTarget"` for Tab 1, followed by `--new-tab "$sidecarUri"` for Tab 2.
- Updated `Show-ToolsExplorer.ps1` to pass `--new-window "$fileUri"` on Zen / Firefox, preventing tab replacement of existing Control Hub sessions.

### 2.3 Short-Name Renaming & Alias Cleanup (`Update-ToolCatalog.ps1`, `LcmDesktopDaemon.ps1`, `DaemonActionController.ps1`)
- Added explicit metadata override in `Update-ToolCatalog.ps1`: `ShortName = "ShowCM"`, `Aliases = @()`, `Example = 'ShowCM'`.
- Implemented `POST /rename` REST endpoint in `LcmDesktopDaemon.ps1` routing to `DaemonActionController.RenameTool($dto)`.
- Enhanced `RenameTool` to persist `ShortName` directly to `LCM_Inventory/config/tool_catalog_overrides.json`.
- Removed stale trampoline scripts `ShowCMControlHub.cmd`, `ShowHub.cmd`, and `ShowCrpDates.cmd` from `LCM_Inventory/Cmd/`, retaining only canonical `ShowCM.cmd`.

### 2.4 Relative-Path Metadata Overrides Resolution (`Update-ToolCatalog.ps1`, `lcm-tool-explorer.js`)
- Updated `Update-ToolCatalog.ps1` to match overrides against normalized relative paths (`$normRel` and `$normRelFwd`), in addition to filename stems.
- Synchronized `Group` and `Domain` properties to both inherit subsystem overrides.
- Updated `finalizeAllBlocked()` in `lcm-tool-explorer.js` to merge cell states into `storedOverrides` before initiating the `/sync_json` daemon call.

### 2.5 Sidecar Lifecycle Filter Hardening (`LCM_SIDECAR.html`)
- Filtered `openCandidates` strictly to active states (`['suggested', 'in_progress', 'staged', 'approved']`), actively rejecting `completed`, `pushed`, `rejected`, `deferred`, `cancelled`, and `abandoned`.
- Added fallback to the highest registered proposal (`proposalsList[proposalsList.length - 1]`) when no active candidates exist.

### 2.6 Sidecar UI Ergonomics (`LCM_SIDECAR.html`)
- Restyled `#proposalSwitcher` as `.proposal-switcher-prominent`: height 48px, bold white typography on `var(--accent-green)` background, `#738a00` border, box-shadow.
- Restructured target banner into a two-row responsive layout:
  - Row 1: Proposal Tag, interactive `Plan State` dropdown, interactive `Proposal Status` dropdown, Scope pill, Priority pill, App pill.
  - Row 2: Full proposal title.
- Implemented `changeSidecarPlanState` and `changeSidecarProgressState` dispatching daemon commands via `Invoke-ProposalAction.ps1`.

### 2.7 Global 12px Scrollbar Standards (`StandardTableDisplay.css`, `CM_CONTROL_HUB.html`, `LCM_SIDECAR.html`)
- Enforced `width: 12px; height: 12px;` scrollbars across all tables.
- Applied `overflow-x: scroll !important;` to `.table-container` in both CSS and HTML files.
- Added `scrollbar-width: auto;` to ensure Firefox/Zen renders standard width scrollbars.

---

## 3. Verification & Compliance
- **Asset Mirroring**: Exact SHA256 match between `LCM_Inventory/assets/` and `LCM_Inventory/assets/`.
- **Zero Syntax Errors**: `Show-ToolsExplorer.ps1 -NoLaunch` and `Show-LcmControl.ps1 -NoLaunch` execute cleanly.
- **REST Telemetry**: Daemon successfully processes `/execute` and `/rename` operations without unhandled exceptions.
