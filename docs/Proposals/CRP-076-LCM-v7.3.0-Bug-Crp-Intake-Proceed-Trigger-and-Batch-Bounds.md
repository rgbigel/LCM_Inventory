# Change Request Proposal: Bug/CRP Intake Gate, PROCEED Trigger Invariants, and Batch Execution Granularity

- **Proposal ID**: `CRP-076`
- **Target Repository**: `LCM` (`Git_Repositories/.agents/rules`, `Workspace_Inventory`)
- **Target Version**: `v7.3.0`
- **Domain**: `Lifecycle Model (LCM) Governance & Proposal Review Flow`
- **Author**: Rolf, Workspace_AI Governance
- **Status**: `ACCEPTED` (Reviewed & Approved by Operator)
- **Created**: `2026-09-05 21:50:00`
- **Priority**: `HIGH`
- **Target Scope**: `.agents/rules/ProposalReviewFlowPolicy.md`
- **Affected Version Range**: `v7.2.0 - v7.3.0`
- **Impacted Repositories**: `Git_Repositories`, `Workspace_Inventory`

---

## 1. Objective & Operational Rationale

This Change Request Proposal formalizes and amends the **Proposal Review Flow Policy** (`ProposalReviewFlowPolicy.md`) to establish an unambiguous, fail-safe intake boundary for user defect reports and change requests.

### Operational Problem (Credit Exhaustion & Mid-Execution Workspace Corruption)
When an operator inputs a batch of feedback items prefaced with `BUG:` or `CRP:`, the AI agent has previously suffered from an over-eagerness trap—conflating defect enumeration or priority notes (such as "*This CRP has highest Priority*") with an authorization to immediately develop implementation plans and execute code modifications across multiple repositories.

Executing large batches of unapproved fixes simultaneously produces critical hazards:
1. **Credit / Token Exhaustion**: Massive multi-issue execution across dozens of files exhausts reasoning quota or token contexts mid-flight.
2. **Unstable Workspace State**: When execution is abruptly terminated by token exhaustion or rate limits, the IDE and Git repositories are left in an uncommitted, partially modified, broken intermediate state.
3. **Bypassing Review Gates**: Architectural changes and complex fixes are applied without the operator having evaluated or approved individual plans.

---

## 2. Policy Amendments to ProposalReviewFlowPolicy.md

To permanently eliminate this failure mode, four authoritative governance rules will be incorporated into `.agents/rules/ProposalReviewFlowPolicy.md`:

### RULE-LCM-015: Strict BUG: and CRP: Intake Gate Invariant
1. **Intake Signal Only**: The appearance of `BUG:` or `CRP:` designators in user input `MUST NEVER` be interpreted as a request to begin analysis, develop an Implementation Plan, or execute code modifications.
2. **Mandatory OPEN Intake**: The AI agent's sole initial responsibility upon receiving `BUG:` or `CRP:` input is to register the items into the Configuration Management ledger (`Workspace_Inventory/data/proposals/proposals.json` and formal specifications under `Workspace_Inventory/docs/Proposals/`) in the **`OPEN`** state (`state: "bug"` or `"suggested"`, `progress_state: "open"`).
3. **Priority Hierarchy**:
   - Items designated `BUG:` `MUST` automatically receive higher initial triage priority than `CRP:` items.
   - Priority markings (including "*highest priority*" or "*critical*") affect ordering only; they `DO NOT` authorize departure from the `OPEN` state.
4. **Prohibition of Premature Planning**: The agent `MUST NOT` generate an `implementation_plan.md` or execute source code changes for any registered item without receiving an explicit activation trigger.

### RULE-LCM-016: Explicit PROCEED and PROCEED ALL Activation Triggers
Proposals held in the `OPEN` state may transition to Implementation Planning and execution `ONLY` upon receiving one of two explicit operator triggers:
1. **`PROCEED <Item/ID>`**:
   - Authorizes implementation planning and subsequent execution for the **single** designated BUG or CRP item only.
   - All other items in the batch remain strictly in the `OPEN` state.
2. **`PROCEED ALL`**:
   - Authorizes execution **strictly for the items positioned ABOVE the `PROCEED ALL` keyword** in the user's prompt or batch submission.
   - `MUST NOT` apply to any items listed below or following the `PROCEED ALL` marker.
3. **Strict Invariant**: In the absence of an explicit `PROCEED` or `PROCEED ALL` trigger, the AI agent `MUST STOP` immediately after intake registration and present the registered items to the operator for document review.

### RULE-LCM-017: Autonomous System Exception Boundary & Loop Breaker
1. **Autonomous Exception Scope**: As a sole exception to `RULE-LCM-016`, the AI agent is permitted to assume an implicit `PROCEED` to immediately remediate a self-discovered or runtime-generated `BUG` `ONLY IF` all of the following conditions are simultaneously met:
   - **Critical System/Transport Behavior**: The defect represents a severe runtime blocker directly disrupting operations (e.g., REST daemon socket drops on Port 9876, IPC transport failures, or blocking background daemon aborts).
   - **Within Agent Capability**: The root cause is definitively identified and remediable within the agent's direct operational scope.
   - **No Architectural Redesign**: The fix requires no architectural redesign, schema changes, or breaking API alterations.
   - **Net Positive Impact**: The fix will not create cascading side-effects or regressions exceeding the problem being solved.
2. **Mandatory 2-Attempt Loop Breaker**:
   - If two (2) consecutive attempts to fix the runtime defect fail to resolve the issue, the autonomous `PROCEED` exception is **immediately and irrevocably revoked**.
   - The agent `MUST HALT` all modification attempts, mark the BUG item as `blocked`/`open` in the ledger, document the failure telemetry, and yield full control back to the operator.

### RULE-LCM-018: Credit Exhaustion & Batch Execution Granularity Guard
1. **Batch Size Safety**: Multi-item batches `MUST` be segmented into manageable, verifiable increments to prevent credit, context, and token exhaustion.
2. **Discrete Review Boundaries**: Each approved proposal or tight batch `MUST` reach a stable, verifiable state before proceeding to subsequent items, guaranteeing that uncommitted or partially modified code never leaves the workspace in an unrecoverable state.

---

## 3. Implementation Deliverables

1. **Rule File Update**:
   - Update `D:\Git_Repositories\.agents\rules\ProposalReviewFlowPolicy.md` (and propagate via canonical junction to all child repos).
   - Increment version to `v7.3.0`.
2. **Rule Matrix & Index Synchronization**:
   - Update `Workspace_AI/docs/LCM-Rules-Cross-Reference.md` and `AGENTS.md` to reflect `RULE-LCM-015` through `RULE-LCM-018`.
3. **Pre-Push AI Export Parity**:
   - Mirror updated rules to `Workspace_AI/docs/LCM_Rules_Gemini_Export.md` and `D:\GDrive\LCM` during the standard pre-push pipeline per `RULE-LCM-013`.
4. **Implementation.md Design Choices Terminal Section**:
   - Append a standardized "Design Choices & Implementation Rationale" section to the end of `Workspace_AI/docs/Implementation.md` (and `.lcm/docs/Implementation.md`) documenting the architectural tradeoffs and rationale behind these intake and execution bounds.

---

## 4. Design Choices & Implementation Rationale (Blueprint for Implementation.md)

The following summary of design choices and alternative analysis must be appended at the end of `Implementation.md`:

| Design Choice | Approach Selected | Alternative Considered | Rationale & Trade-Off Analysis |
| :--- | :--- | :--- | :--- |
| **Defect Intake Gate** | **Mandatory `OPEN` State on `BUG:` / `CRP:` Designators (`RULE-LCM-015`)** | Immediate analysis, plan generation, or immediate code modification | Operator bug enumerations are reports, not work orders. Immediate execution causes credit exhaustion, premature code mutations, and unapproved refactorings. Mandating `OPEN` state ensures complete intake and explicit operator control. |
| **Activation Trigger Scope** | **Directional `PROCEED ALL` (strictly applies ABOVE keyword) (`RULE-LCM-016`)** | Global `PROCEED ALL` applying to all items in prompt or active session | Operators often provide subsequent notes, deferred items, or caveats below `PROCEED ALL`. Restricting `PROCEED ALL` strictly to items listed *above* the marker guarantees no unintended downstream items are executed. |
| **Single-Item Activation** | **`PROCEED <Item/ID>` (`RULE-LCM-016`)** | Automatic batch cascading | Authorizing single items allows tight, discrete step-by-step verification without consuming full session quota across unreviewed items. |
| **Runtime Bug Remediations** | **Autonomous Exception strictly for Critical System/Transport Issues (`RULE-LCM-017`)** | Universal strict stop on all errors, OR uncontrolled autonomous patching | A hard stop on every transient local connection blip (e.g. REST daemon Port 9876 drop) freezes automation unnecessarily. Restricting autonomous proceed strictly to critical system/transport issues avoids deadlock while preventing runaway code rewrites. |
| **Runaway Loop Protection** | **Hard 2-Attempt Loop Breaker (`RULE-LCM-017`)** | Unlimited retry attempts, or heuristic retry counts | If a runtime defect cannot be resolved in 2 attempts, the failure is structural or environmental. Halting immediately and marking the item `blocked`/`open` stops token exhaustion and prevents catastrophic file thrashing. |
| **Batch Size Execution Guard** | **Discrete Batch Granularity (`RULE-LCM-018`)** | Monolithic multi-proposal execution | Monolithic execution of large defect lists risks mid-flight credit/token exhaustion, leaving repositories in an uncommitted, dirty, broken state. Discrete batches ensure each accepted change is safely verified and committed. |

---

## 5. Verification & Review Flow

1. **Document Review Gate**: Operator inspects this specification (`CRP-076`) in `Workspace_Inventory/docs/Proposals/`.
2. **Review Disposition**: Operator renders a decision (`ACCEPT`, `CHANGE`, or `REJECT`).
3. **Execution Gating**: **NO CODE OR RULE MODIFICATIONS** will take place until the operator explicitly reviews and accepts this document.


