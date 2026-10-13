# Implementation Plan: BUG-216 ShowCM Action Dispatch and Daemon Communication Failure

Module: LCM_Inventory/assets/CM_CONTROL_HUB.html  
Purpose: Step-by-step implementation blueprint to re-route ShowCM action dispatches, harden daemon error handling, and support held/deferred states.  
Path: LCM_Inventory/docs/Proposals/BUG-216-ShowCM-Action-Dispatch-and-Daemon-Communication-Failure/Implementation_Plan.md  
Authors: rgbig, LCM_AI Engine  
Version: 10.0.0
Status: Authoritative Plan  
Date: 2026-10-13
App: App: 1 - CM Interactive Control Hub  

---

## 1. Constituent Manifest Table

| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `LCM_Inventory/assets/CM_CONTROL_HUB.html` | Presentation Template | `dispatchStandardAction`, `executeDaemonCommand`, `confirmHoldAction` | Manual UI Testing |
| `LCM_Inventory/data/artifacts/CM_CONTROL_HUB.html` | Compiled Runtime Artifact | Served over `GET /hub` on Port 9876 | Daemon Integration Tests |
| `LCM_Inventory/tools/Invoke-ProposalAction.ps1` | Execution Tool | `Invoke-ProposalAction` | `tests/ProposalManager.Tests.ps1` |
| `LCM_Inventory/modules/ProposalManager.psm1` | Core Module | `Invoke-ProposalBatchAction`, `Set-WorkspaceProposalState`, `Set-WorkspaceProposalProgress` | `tests/ProposalManager.Tests.ps1` |

---

## 2. Phase Breakdown

### Phase 1: Backend Parameter & State Validation Fixes
1. In [`LCM_Inventory/modules/ProposalManager.psm1`](file:///d:/Git_Repositories/LCM_Inventory/modules/ProposalManager.psm1):
   - Add `'held'` to `ValidateSet` of `State` in `Set-WorkspaceProposalState`.
   - Add `'deferred'` to `ValidateSet` of `ProgressState` in `Set-WorkspaceProposalProgress`.
   - Add `'hold'`, `'held'` to `ValidateSet` of `Action` in `Invoke-ProposalBatchAction`.
   - In `Set-WorkspaceProposalProgress`, ensure transitioning to `in_progress` from `held` or `deferred` sets plan state to `approved`.
2. In [`LCM_Inventory/tools/Invoke-ProposalAction.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-ProposalAction.ps1):
   - Add `'hold'`, `'held'` to `ValidateSet` on `-Action`.
   - Add `'held'` to `ValidateSet` on `-State`.
   - Add `'deferred'` to `ValidateSet` on `-ProgressState`.

### Phase 2: Frontend Command Routing & Daemon Error Trapping
1. In [`LCM_Inventory/assets/CM_CONTROL_HUB.html`](file:///d:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB.html):
   - Replace fictitious script paths in `dispatchStandardAction()` with canonical `pwsh -NoProfile -ExecutionPolicy Bypass -File LCM_Inventory/tools/Invoke-ProposalAction.ps1`.
   - Re-route `purge_temp` to [`Clear-BCReviewTemp.ps1 -Purge`](file:///d:/Git_Repositories/LCM_Inventory/tools/Clear-BCReviewTemp.ps1).
   - In `executeDaemonCommand()`, inspect `data.status === "ERROR"`, `data.exitCode !== 0`, and `data.stderr` to trigger visible alerts and halt silent auto-refresh.
   - Re-route `confirmHoldAction()` to `Invoke-ProposalAction.ps1 -Action hold -TargetExpression "<ids>" -Details "<reason>"`.
   - In row action dropdown:
     - Route `showProposalWalkthrough()` to modal cache lookup (`docsCache`).
     - Route `showProposalDiff()` to [`Invoke-BeyondCompareReview.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1).
2. Bump template version in header to `10.0.0` (Date: `2026-10-13`).

### Phase 3: Artifact Recompilation & Verification
1. Run [`LCM_Inventory/tools/Show-LcmControl.ps1 -NoLaunch`](file:///d:/Git_Repositories/LCM_Inventory/tools/Show-LcmControl.ps1) to compile `data/artifacts/CM_CONTROL_HUB.html`.
2. Verify live daemon endpoint `http://127.0.0.1:9876/hub` serves Version `10.0.0`.
3. Verify `Invoke-RestMethod` execution of `Invoke-ProposalAction.ps1 -Action do -TargetExpression "201"` returns exit code 0.
