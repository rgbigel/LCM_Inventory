# Implementation Plan: Proposal #79 (CRP-2026-023)
## CM Control Hub Compact Prio Column (C/H/M/L/D), Filtering, Sorting & Persistence Engine

### 1. Goal
Add a dedicated, space-conserving **`Prio`** column using single-letter priority codes (`C`, `H`, `M`, `L`, `D`) to `CM_CONTROL_HUB.html`, wire up column header filtering and deterministic sorting, support real-time row dropdown persistence via Desktop Daemon, and update PowerShell ledger tooling (`ProposalManager.psm1`, `Invoke-ProposalAction.ps1`).

---

### 2. User Review Required
> [!NOTE]
> Single-letter codes:
> - **C**: Critical
> - **H**: High
> - **M**: Medium (Default)
> - **L**: Low
> - **D**: Designated for later

---

### 3. Proposed Changes

#### [MODIFY] [ProposalManager.psm1](file:///D:/Git_Repositories/LCM_Inventory/modules/ProposalManager.psm1)
- Add `Set-WorkspaceProposalPriority` cmdlet supporting `[ValidateSet('C', 'H', 'M', 'L', 'D')]`.
- Standardize ledger serialization.

#### [MODIFY] [Invoke-ProposalAction.ps1](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-ProposalAction.ps1)
- Add `-Action priority` with `-Priority <C|H|M|L|D>` parameter.

#### [MODIFY] [proposals.json](file:///D:/Git_Repositories/LCM_Inventory/data/proposals/proposals.json)
- Register Proposal #79 (`state: "in_progress"`, `progress_state: "in_progress"`).
- Backfill existing proposals with canonical priority codes (`High` ➔ `H`, `MEDIUM` ➔ `M`, unassigned ➔ `M`, BUGs without priority ➔ `H`).

#### [MODIFY] [CM_CONTROL_HUB.html](file:///D:/Git_Repositories/LCM_Inventory/docs/CM_CONTROL_HUB.html)
- Add `Prio` `<th>` with filter dropdown and sort toggle (`Prio ⬍`).
- Add `.prio-select` styling for `C`, `H`, `M`, `L`, `D`.
- Render `Prio` cell in table rows with interactive `<select>`.
- Wire `changeProposalPriority(id, prio)` to call Desktop Daemon on Port 9876.
- Add `prio #<id> <code|1-5>` command in interactive console.
- Add sorting comparator function for priority order `C > H > M > L > D`.

---

### 4. Verification Plan
- Validate `proposals.json` JSON schema.
- Validate `CM_CONTROL_HUB.html` JavaScript AST with Node.js parser.
- Test `Invoke-ProposalAction.ps1 -Action priority -TargetExpression 79 -Priority H`.
- Confirm visual table layout and responsive column widths.
