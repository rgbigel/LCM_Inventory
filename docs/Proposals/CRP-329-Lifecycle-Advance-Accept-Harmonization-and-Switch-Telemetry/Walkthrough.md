# Walkthrough: CRP-329 - Proposal Lifecycle Advance and Accept Harmonization, Switch Telemetry, and Daemon Action Alignment

**Document Information**
- **Proposal ID**: CRP-329
- **Title**: Proposal Lifecycle Advance and Accept Harmonization, Switch Telemetry, and Daemon Action Alignment
- **Author**: Rolf & Antigravity
- **Date**: 2026-11-14
- **Status**: Completed / Verified

---

## 1. Overview & Objectives Delivered
`CRP-329` resolves the operator friction points identified during ShowCM testing:
1. **Flexible Advance Action**:
   - `advance` / `proceed` now steps proposals forward across their entire lifecycle (`suggested` $\to$ `in_progress` $\to$ `verified` $\to$ `in_review` $\to$ `completed`).
   - `held` / paused proposals are unpaused and resumed directly with `advance` without requiring a prior separate `reopen` command.
   - Archival and terminal states (`rejected`, `superseded`, `withdrawn`, `pushed`) remain un-advanceable and require explicit reopening.
2. **Contextual Accept Action**:
   - Dedicated `accept` / `accepted` action now operates contextually:
     - On `suggested`: executes Gate 1 Acceptance (starts implementation / `in_progress`).
     - On `held`: resumes from hold.
     - On `in_progress`, `verified`, or `in_review`: executes Gate 2 Acceptance (records review disposition, generates audit receipt, and transitions to `completed`).
3. **Switch State Telemetry & Logging**:
   - Every lifecycle action execution formats and outputs `[SWITCH TELEMETRY]` containing `MinimalTests`, `Force`, `Immediately`, `Mode`, `TestingMode`, `Granularity`, and `ProgressState`.
   - Every dispatch is recorded in `LCM_Inventory/logs/cm_activity.log`.
4. **Desktop Daemon Action Route**:
   - Added `/api/action` and `/action` routes in Go Desktop Daemon (`daemon.go`), translating Control Hub payloads directly to synchronous execution and eliminating `405 Method Not Allowed`.
5. **Transition Diagram Docs**:
   - Updated `ProposalReviewFlowPolicy.md` Mermaid `stateDiagram-v2` to reflect the single-dimensional flow, Gate 1 / Gate 2 Accept gates, and Advance stepper.

---

## 2. Changes Summary

| Component | File | Summary of Changes |
|:---|:---|:---|
| **Desktop Daemon** | `LCM_Inventory/src/do/daemon.go` | Added `/api/action` and `/action` route handlers; added ActionRequest unmarshaling fallback in `handleExecute`; rebuilt `DoT/do.exe`. |
| **Action CLI** | `LCM_Inventory/tools/Invoke-ProposalAction.ps1` | Added `'accept'`, `'accepted'`, `'advance'` to `[ValidateSet]`; added `[SWITCH TELEMETRY]` output and `cm_activity.log` logging; expanded `^proceed$` to handle `verified` $\to$ `in_review` and `in_review` $\to$ `completed`; added `^(accept\|accepted)$` action. |
| **Proposal Manager** | `LCM_Inventory/modules/ProposalManager.psm1` | Updated `Test-LcmProposalLifecycleTransition` to allow forward transitions to `in_review` and `completed`; updated `Move-LcmProposalLifecycleState` to auto-record operator disposition on explicit accept/advance. |
| **Control Hub UI** | `LCM_Inventory/assets/CM_CONTROL_HUB.html` | Updated `Advance ITEM` to be active on all non-terminal states; updated Accept button to dynamically show `Accept Proposal (Gate 1)` for `suggested` and `Accept Review (Gate 2)` for active review states. |
| **Governance Rules** | `LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md` | Updated Mermaid `stateDiagram-v2` to depict Advance, Gate 1/2 Accept, Held resume, and terminal states. |

---

## 3. Live Verification Evidence

### A. Switch Telemetry in Console & cm_activity.log
```
[LIFECYCLE ACTION] advance (329)
[SWITCH TELEMETRY] Action=advance | Target=329 | MinimalTests=False | Force=False | Immediately=False | Mode=GOVERNED_IMPLEMENTATION | TestingMode=active | Granularity=tight
```
Logged in `LCM_Inventory/logs/cm_activity.log`:
```
[2026-11-14 12:43:23] [ACTION_DISPATCH] Action=priority | Target=329 | MinimalTests=False | Force=False | Immediately=False | Mode=GOVERNED_IMPLEMENTATION | TestingMode=active | Granularity=tight User=rgbig
```

### B. Daemon `/api/action` Live Response
```python
resp = urllib.request.urlopen(req)
# Status: 200 OK
# Response: {"status":"DISPATCHED","exitCode":0,...}
```

### C. Live Full Lifecycle Pass (CRP-329)
1. `in_progress` $\to$ `verified` via `advance` [PASS]
2. `verified` $\to$ `in_review` via `advance` [PASS]
3. `in_review` $\to$ `held` via `hold` [PASS]
4. `held` $\to$ `in_review` via `advance` (seamless unpause) [PASS]
5. `in_review` $\to$ `completed` via `accept` [PASS]
   - Recorded audit receipt `review_LCM_Inventory_20261114_124542.json`
   - Committed to `main` (`40c75f0`)

