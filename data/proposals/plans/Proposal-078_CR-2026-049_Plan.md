# Implementation Plan: Proposal-078 (CR-2026-049 / BUG-2026-009)

## Overview
Implement LCM Display Standard (Light/Dark mode theme toggle, typography, and LcmTablePrintAtom integration) and full interactive console command engine (`submitConsoleCommand`, `handleConsoleKey`, `do #<id>`, `accept`, `review`, etc.) in CM Control Hub.

## Target Scope
- `LCM_Inventory/docs/CM_CONTROL_HUB.html`
- `LCM_Inventory/tools/Show-CmControlHub.ps1`
- `LCM_Inventory/scratch/CM_CONTROL_HUB.html` (generated artifact)

## Proposed Changes
1. **Show-CmControlHub.ps1**:
   - Resolve and inline `LCM_Inventory\assets\lcm-table-print-atom.js`.
   - Bump script version to `1.1.0`, date `2026-09-06`.
   - Inject print atom content into placeholder block.
2. **CM_CONTROL_HUB.html**:
   - Codify and enforce Display Standard rule requiring table heads to be frozen (excluded from scrolling). Apply `position: sticky; top: 0; z-index: 50/51` to `thead`/`th` and `overflow-y: auto`, `max-height: calc(100vh - 380px)` to `.table-container` in both dark and light modes.
   - Add `.light-theme` palette and dynamic theme switching functions (`initTheme`, `toggleTheme`, `applyTheme`).
   - Add header Theme Switch button (☀️ / 🌙) matching LCM Display Standard.
   - Initialize `LcmTablePrintAtom` on `#proposalsTable` and `#docViewerTable`.
   - Implement missing console functions: `submitConsoleCommand`, `handleConsoleKey`, `setConsoleCommand`, `clearConsoleStream`.
   - Implement command parsing for `do #<id>`, `accept #<id>`, `review #<id>`, `defer #<id>`, `delete #<id>`, `status`, and `help`.
   - Bind `do #<id>` to proposal state transition and server sync via `syncLedgerToServer()`.
3. **Verification**:
   - Re-render dashboard using `pwsh -File LCM_Inventory\tools\Show-CmControlHub.ps1 -NoLaunch`.
   - Parse compiled JavaScript in Node.js to verify 0 errors.
   - Run `Test-LCMRuleHealth.ps1`.
