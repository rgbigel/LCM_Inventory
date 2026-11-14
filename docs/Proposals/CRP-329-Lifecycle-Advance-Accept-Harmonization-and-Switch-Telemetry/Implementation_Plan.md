# Implementation Plan: CRP-329

## 1. Scope & Execution Plan
1. **Daemon Endpoint Alignment (`LCM_Inventory/src/do/daemon.go`)**:
   - Add `/api/action` and `/action` routes in Go daemon.
   - Accept either `ExecuteRequest` or `ActionRequest` and execute command synchronously.
   - Build `do.exe` and test `/api/action` endpoint.
2. **Lifecycle Transitions & Accept/Advance (`LCM_Inventory/tools/Invoke-ProposalAction.ps1` & `ProposalManager.psm1`)**:
   - In `Invoke-ProposalAction.ps1`:
     - Add `^(accept|accepted)$` action (Gate 1 on `suggested`; Gate 2 on `in_progress`/`verified`/`in_review`).
     - Expand `^proceed$` to handle `verified` $\to$ `in_review`, and `in_review` $\to$ `completed` via `Submit-ReviewResult.ps1`.
     - Expand `held` progression to resume and advance.
     - Add `[SWITCH TELEMETRY]` console logging and `cm_activity.log` ledger entry.
   - In `ProposalManager.psm1`:
     - Allow transitions `in_progress` $\to$ `in_review`/`completed`, and `verified` $\to$ `completed`.
3. **Control Hub UI (`LCM_Inventory/assets/CM_CONTROL_HUB.html`)**:
   - Update `Proceed ITEM` to be active for all non-terminal states (`!['completed', 'pushed', 'withdrawn', 'rejected', 'superseded'].includes(lifecycleState)`).
   - Update `ACCEPTED: Item` to show contextually:
     - `Accept Proposal (Gate 1)` for `suggested`
     - `Accept Review (Gate 2)` for `in_progress`, `verified`, `in_review`.
4. **Transition Diagram Docs**:
   - Update `LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md` Mermaid `stateDiagram-v2`.
5. **Testing & Verification**:
   - Run Pester tests.
   - Verify `/api/action` live via curl.
   - Author `Walkthrough.md`.
