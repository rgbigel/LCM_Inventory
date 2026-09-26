# Implementation Plan: BUG-181 Tool Explorer and Control Hub Ergonomics, Window Collision Isolation, Short-Name Renaming, and Lifecycle Defect Remediation

## Proposed Changes

### 1. Workspace_Inventory & .lcm Presentation Assets
- Update `LCMToolCatalog.css` and `.lcm/assets/LCMToolCatalog.css` with dark mode Reset button styling.
- Update `lcm-tool-explorer.js` and `.lcm/assets/lcm-tool-explorer.js` with inline styles and `finalizeAllBlocked` override merging.
- Update `StandardTableDisplay.css` and `.lcm/assets/StandardTableDisplay.css` with 12px scrollbars and `overflow-x: scroll !important`.
- Update `CM_CONTROL_HUB.html` with `.table-container` 12px scrollbar rules and `overflow-x: scroll !important`.
- Update `LCM_SIDECAR.html` with:
  - 12px scrollbars and `scrollbar-width: auto`.
  - Prominent 2-line `#proposalSwitcher` styled with Complete button green coloring.
  - Interactive top-row `Plan State` and `Proposal Status` dropdowns.
  - Candidate proposal filtering excluding rejected/deferred items.
  - Live daemon command dispatch for state updates.

### 2. Desktop Dispatch & Browser Isolation
- Update `tools/Show-LcmControl.ps1` to launch Zen Browser / Firefox with `--new-window` for Tab 1 and `--new-tab` for Tab 2.
- Update `.lcm/tools/internal/Show-ToolsExplorer.ps1` to pass `--new-window` on Zen Browser / Firefox.

### 3. Tool Catalog Engine & REST Daemon
- Update `.lcm/tools/internal/Update-ToolCatalog.ps1`:
  - Relative-path lookup in `$metadataOverrides`.
  - Canonical `ShortName = "ShowCM"` and empty aliases `Aliases = @()`.
- Add `POST /rename` route in `.lcm/tools/internal/LcmDesktopDaemon.ps1`.
- Add `RenameTool` logic in `.lcm/modules/LcmDaemon/Classes/DaemonActionController.ps1` persisting to `tool_catalog_overrides.json`.
- Delete obsolete trampolines `ShowCMControlHub.cmd`, `ShowHub.cmd`, and `ShowCrpDates.cmd` from `.lcm/Cmd/`.

### 4. Verification & Ledger Registration
- Register `BUG-181` in `Workspace_Inventory/data/proposals/proposals.json`.
- Verify SHA256 hashes across mirrored assets.
- Test dashboard rendering with `-NoLaunch`.

---

## Verification Plan

### Automated Tests
- Run `Show-ToolsExplorer.ps1 -NoLaunch` to verify tool catalog compilation and HTML output.
- Run `Show-LcmControl.ps1 -NoLaunch` to verify Control Hub and Sidecar compilation.
- Run hash validation script comparing `Workspace_Inventory/assets/` against `.lcm/assets/`.

### Manual / Visual Verification
- Inspect Reset button in dark mode to confirm dark `#0d1117` background with red `#f85149` text.
- Launch `Show-ToolsExplorer.ps1` while `Show-LcmControl.ps1` is open; verify two independent Zen Browser windows.
- In Sidecar, verify the prominent green proposal switcher and interactive state dropdowns.
