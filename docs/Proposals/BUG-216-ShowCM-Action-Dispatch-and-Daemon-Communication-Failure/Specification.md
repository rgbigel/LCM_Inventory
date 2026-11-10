# BUG-216: ShowCM Action Dispatch and Daemon Communication Failure for Proposals

```yaml
CRP-ID: BUG-216
Title: ShowCM Action Dispatch and Daemon Communication Failure for Proposals
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-13 12:36:04
Status: Superseded
Plan-State: superseded
Progress-State: deferred
Priority: High
App-ID: App: 1
```

Module: LCM_Inventory/assets/CM_CONTROL_HUB.html  
Purpose: Fix ShowCM proposal lifecycle action dispatching to non-existent scripts, correct silent error swallowing in executeDaemonCommand, and validate held/deferred lifecycle states in backend tools.  
Path: LCM_Inventory/docs/Proposals/BUG-216-ShowCM-Action-Dispatch-and-Daemon-Communication-Failure/Specification.md  
Authors: rgbig, LCM_AI Engine  
Version: 10.0.0
Status: Authoritative Specification  
Date: 2026-10-13
App: App: 1 - CM Interactive Control Hub  

---

## 1. Problem Statement

When operating on proposals within the interactive LCM Control Hub (`ShowCM` / `http://localhost:9876/hub`), triggering lifecycle actions (such as `Start (do)` in the bulk action panel or the row-level `Actions...` dropdown for proposal `#201` in state `held`, `deferred`) resulted in no observable state transition or execution.

Diagnostics revealed three distinct failure layers:
1. **Fictitious Script Invocations**: `CM_CONTROL_HUB.html` generated shell command strings targeting non-existent scripts:
   - `pwsh tools/Do-Proposal.ps1 -Id <id>`
   - `pwsh tools/Proceed-Proposal.ps1 -Id <id>`
   - `pwsh tools/Show-ProposalDiff.ps1 -Id <id>`
   - `pwsh tools/Hold-Proposal.ps1 -Id <id>`
   - `pwsh tools/Delete-Proposal.ps1 -Id <id>`
   The authoritative tool is [`LCM_Inventory/tools/Invoke-ProposalAction.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-ProposalAction.ps1).
2. **Silent Failure Swallowing**: `executeDaemonCommand()` sent requests to `POST /execute` on the Port 9876 daemon. When the command failed (`exitCode: 1`), the daemon returned `status: "ERROR"` and `stderr: "..."`. The frontend checked only `if (data.error)`, which was undefined, causing it to fall through to `setTimeout(refreshHubData, 600)`, giving the false appearance of a successful action while nothing changed.
3. **Backend Validation Gaps**: In [`LCM_Inventory/tools/Invoke-ProposalAction.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-ProposalAction.ps1) and [`LCM_Inventory/modules/ProposalManager.psm1`](file:///d:/Git_Repositories/LCM_Inventory/modules/ProposalManager.psm1), `ValidateSet` attributes for `Action`, `State`, and `ProgressState` did not include `held` or `deferred`, causing runtime parameter validation errors when attempting to hold or reactivate proposals.

---

## 2. Requirements & Normative Constraints

1. **Deterministic Command Routing**: All lifecycle action triggers (`do`, `proceed`, `complete`, `delete`, `defer`, `hold`) `MUST` dispatch to `pwsh -NoProfile -ExecutionPolicy Bypass -File LCM_Inventory/tools/Invoke-ProposalAction.ps1` with valid `-Action` and `-TargetExpression` arguments.
2. **Authoritative Error Trapping**: `executeDaemonCommand()` `MUST` evaluate `data.status === "ERROR"`, `data.exitCode !== 0`, and `data.stderr`. Any non-zero exit code or execution error `MUST` alert the operator with full diagnostic text and halt optimistic UI refreshes.
3. **Dual-State Validation Completeness**:
   - `Set-WorkspaceProposalState` `MUST` accept `held`.
   - `Set-WorkspaceProposalProgress` `MUST` accept `deferred`.
   - `Invoke-ProposalAction.ps1` `MUST` accept `hold` and `held` in `-Action`, and `held` in `-State`.
4. **Reactive State Transition on `do`**: When `do` is triggered on a `held` or `deferred` proposal, it `MUST` reactivate the proposal to `state: approved` (or `processed`) and `progress_state: in_progress`.
5. **Wand Action Integrity**: "Show Walkthrough" `MUST` display the compiled markdown walkthrough from `docsCache` in the document modal, and "Show Diff / BC Review" `MUST` dispatch [`Invoke-BeyondCompareReview.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1).

---

## 3. Architecture & Data Flow

```
[ Operator in ShowCM Web UI ]
             │
             ▼
  handleBulkAction('do') / handleSingleItemAction(id, 'do')
             │
             ▼
  dispatchStandardAction('do', [id])
             │
             ▼ Formats Canonical Command:
  pwsh -NoProfile -ExecutionPolicy Bypass -File LCM_Inventory/tools/Invoke-ProposalAction.ps1 -Action do -TargetExpression "<id>"
             │
             ▼
  executeDaemonCommand() ─── POST /execute ───► [ Port 9876 Daemon ]
             ▲                                         │
             │ Validates exitCode & status             ▼ Synchronous Exec
             └───────────────────────────────── [ Invoke-ProposalAction.ps1 ]
                                                       │ Updates State & Progress
                                                       ▼
                                            [ proposals.json ]
```
