# Walkthrough: BUG-181 Tool Explorer and Control Hub Ergonomics, Window Collision Isolation, Short-Name Renaming, and Lifecycle Defect Remediation

## Overview
This walkthrough confirms the end-to-end resolution of eight defect areas across the LCM Configuration Management toolsuite:

1. **Tool Explorer Reset Button Styling**:
   - Verified that the `Reset` button in dark mode renders with a dark `#0d1117` background, a subtle red border (`rgba(248,81,73,0.4)`), and vibrant red text (`#f85149`), matching the operator specification.

2. **Zen Browser Window Collision Isolation**:
   - `Show-LcmControl.ps1` dispatches Tab 1 with `--new-window` and Tab 2 with `--new-tab`.
   - `Show-ToolsExplorer.ps1` dispatches with `--new-window`.
   - Result: Launching ToolsExplorer while Control Hub is open preserves the existing Control Hub session in an independent window.

3. **Short-Name Renaming & Launcher Cleanup**:
   - `Show-LcmControl.ps1` now possesses canonical `ShortName: "ShowCM"`, `Aliases: []` (0 aliases).
   - Obsolete cmdlets `ShowCMControlHub.cmd`, `ShowHub.cmd`, and `ShowCrpDates.cmd` removed from `LCM_Inventory/Cmd/`.
   - Daemon `/rename` route added and wired to `tool_catalog_overrides.json`.

4. **Subsystem Overrides Persistence**:
   - `Update-ToolCatalog.ps1` resolves metadata overrides by relative file path.
   - `finalizeAllBlocked()` in `lcm-tool-explorer.js` merges pending edits into overrides before triggering `/sync_json`.
   - Changing `Workspace*` tools to `LCM` subsystem and clicking `SetAll` now persists cleanly across catalog recompilation.

5. **Sidecar Open Proposal Selection**:
   - Open candidate filter strictly selects proposals with active states (`suggested`, `in_progress`, `staged`, `approved`), excluding `rejected`, `deferred`, `cancelled`, and `abandoned`.
   - Defaults to the latest registered proposal when no active proposals remain, preventing stale proposal `122` selection.

6. **Prominent Proposal Switcher**:
   - `#proposalSwitcher` upgraded to a 2-line prominent control (height 48px, bold white text on `var(--accent-green)` background with `#738a00` border), matching the Complete button visual prominence.

7. **Sidecar Plan State & Status Dropdowns**:
   - Added interactive `Plan State` and `Proposal Status` dropdowns to the top row of the Sidecar target banner.
   - Wired dropdown changes directly to `Invoke-ProposalAction.ps1` via daemon `/execute` endpoint.

8. **Permanent 12px Scrollbars**:
   - Standardized `12px` scrollbars and `overflow-x: scroll !important` across `StandardTableDisplay.css`, `CM_CONTROL_HUB.html`, and `LCM_SIDECAR.html`.

---

## Verification Summary
- **Compilation Check**: `Show-ToolsExplorer.ps1 -NoLaunch` and `Show-LcmControl.ps1 -NoLaunch` passed with zero errors.
- **SHA256 Mirror Parity**: 100% hash parity verified across `LCM_Inventory/assets/` and `LCM_Inventory/assets/`.
