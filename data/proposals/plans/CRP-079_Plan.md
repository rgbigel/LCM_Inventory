# Implementation Plan: CRP-079
## CM Control Hub Architectural Overhaul, Unified CRP Identifier, Silent Daemon & Status Engine

### 1. Goal
Consolidate and finalize the operator-approved UX polish and architectural enhancements under unified sequence identifier **`CRP-079`**:
1. **CRP ID Unification**: Unify ticket sequences under format `CRP-079`. Merge separate `ID` and `CR/CRP ID` table columns into a single clean `CRP ID` column displaying `CRP-NNN`.
2. **Column Heading `STATUS`**: Rename `Progress` to `STATUS`. Simplify filter option from `Open - (non-completed)` to `Open`.
3. **`COMMITTED` State**: Formalize explicit lifecycle state `committed` between `verification` and `pushed` (`in_progress` -> `verification` -> `committed` -> `pushed`).
4. **High-Contrast Live Feedback Ticker**: Add bright yellow-on-black feedback ticker in toolbar next to `Reset to SHOW ALL` displaying action results and out-of-view notifications.
5. **Silent Process Execution**: Silence Desktop Daemon `/execute` command windows (`WindowStyle = Hidden`).
6. **Header Layout**: Prevent `<h1>` wrapping, move Daemon status to top-right unboxed text, and maintain clean spacing for pill toggles.
7. **Status Reopening Sync**: Automatically reset Plan State from `completed`/`pushed` to `suggested` when status reverts to `in_progress`.
8. **Terminology Transition**: Adopt "CRP" throughout UI labels and documentation.

---

### 2. User Review Required
- Operator issued explicit `PROCEED` with directive: "the shorter, the better: CRP-079 is best."

---

### 3. Proposed Changes
- **`LcmDaemon/Classes/DaemonDto.ps1`**: Added `[string]$WindowStyle` parameter to `DaemonExecuteRequest`.
- **`LcmDaemon/Classes/DaemonActionController.ps1`**: Defaulted `$windowStyle` to `Hidden` for non-elevated background execution.
- **`Workspace_Inventory/modules/ProposalManager.psm1`**:
  - Added `committed` and `pushed` to `Set-WorkspaceProposalProgress` ValidateSet.
  - Added reopening sync (reverting progress resets plan state to `suggested`).
  - Added `CRP-` prefix stripping in `Resolve-ProposalIdExpression`.
  - Updated `Format-ProposalsTable` to show `CRP ID` (`CRP-NNN`) and `STATUS`.
- **`Workspace_Inventory/tools/Invoke-ProposalAction.ps1`**:
  - Added `commit` and `committed` actions and `committed` progress state.
- **`Workspace_Inventory/docs/CM_CONTROL_HUB.html`**:
  - Merge `ID` + `CRP ID` columns into single `CRP ID` column.
  - Rename `Progress` heading to `STATUS`.
  - Add `committed` badge, styling, and dropdown options.
  - Add live yellow-on-black feedback ticker in toolbar with out-of-view alert.
  - Prevent `<h1>` wrapping with `white-space: nowrap;`.
  - Relocate Daemon status to top-right unboxed text.
  - Wire status revert sync in `changeProgressState`.
- **`Workspace_Inventory/data/proposals/proposals.json`**:
  - Registered CRP-079 in `in_progress` state.

---

### 4. Verification Plan
- Syntax and AST validation on `CM_CONTROL_HUB.html`.
- Run `Show-CmControlHub.ps1 -NoLaunch` to regenerate `scratch/CM_CONTROL_HUB.html`.
- Test CLI and daemon execution for `CRP-079`.
