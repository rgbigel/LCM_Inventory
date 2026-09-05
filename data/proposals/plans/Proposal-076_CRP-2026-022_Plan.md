# Implementation Plan: CRP-2026-022 (Bug/CRP Intake Gate, PROCEED Trigger Invariants, Batch Execution Bounds & Design Choices Documentation)

Execute the approved change request specification [`CRP-2026-022-LCM-v7.3.0-Bug-Crp-Intake-Proceed-Trigger-and-Batch-Bounds.md`](file:///D:/Git_Repositories/Workspace_Inventory/docs/Proposals/CRP-2026-022-LCM-v7.3.0-Bug-Crp-Intake-Proceed-Trigger-and-Batch-Bounds.md) to permanently establish intake boundaries, directional trigger semantics, credit exhaustion guards, and standardized documentation of design choices in `Implementation.md`.

## User Review Required

> [!NOTE]
> This plan formalizes the `BUG:` and `CRP:` intake gates, directional `PROCEED ALL` bounds (strictly items *above* the keyword), autonomous runtime system exceptions with a 2-attempt loop breaker, credit exhaustion guards, and mandatory design choices documentation at the end of `Implementation.md`.
>
> In accordance with `RULE-LCM-014` and Planning Mode, execution will strictly pause until you provide explicit approval to execute this plan.

---

## Proposed Changes

### Governance Policies & Rules (`Git_Repositories/.agents/rules/`)

#### [MODIFY] [ProposalReviewFlowPolicy.md](file:///D:/Git_Repositories/.agents/rules/ProposalReviewFlowPolicy.md)
- Bump version from `7.2.0` to `7.3.0`, update date to `2026-09-05`.
- Add **`RULE-LCM-015: Strict BUG: and CRP: Intake Gate Invariant`**:
  - `BUG:` and `CRP:` prefixes in operator prompts are intake signals only; strictly prohibit immediate analysis, implementation planning, or code execution.
  - Mandatory registration into CM ledger in `OPEN` state (`state: "bug"` or `"suggested"`, `progress_state: "open"`).
  - Priority hierarchy: `BUG:` items receive higher initial triage priority than `CRP:`, but remain in `OPEN` state regardless of priority level.
- Add **`RULE-LCM-016: Explicit PROCEED and PROCEED ALL Activation Triggers`**:
  - `PROCEED <Item/ID>` authorizes planning & execution strictly for that single item.
  - `PROCEED ALL` authorizes execution **strictly for items listed ABOVE the `PROCEED ALL` marker**; never applies to items below it.
  - Mandatory stop: In the absence of an explicit `PROCEED` or `PROCEED ALL` keyword, the agent must halt after intake registration.
- Add **`RULE-LCM-017: Autonomous System Exception Boundary & 2-Attempt Loop Breaker`**:
  - Agent may assume implicit `PROCEED` only for critical system/transport failures (e.g. daemon port 9876 socket drop, IPC transport failure).
  - Strict constraints: within capability, no redesign, net-positive impact.
  - **2-Attempt Loop Breaker**: If 2 attempts fail to resolve the defect, autonomous proceed is revoked; agent must halt, mark the bug `blocked`/`open`, and yield to operator.
- Add **`RULE-LCM-018: Credit Exhaustion & Batch Execution Granularity Guard`**:
  - Mandatory batch segmentation to prevent mid-flight token/credit exhaustion and corrupt, uncommitted workspace states.

---

### Root Governance & Cross-Reference Matrices

#### [MODIFY] [AGENTS.md](file:///D:/Git_Repositories/AGENTS.md)
- Update Quick-Reference table row for `ProposalReviewFlowPolicy.md` from `RULE-LCM-001` - `014` to `RULE-LCM-001` - `018`.
- Include summary of intake gates, `PROCEED ALL` directional bounds, loop-breaker, and batch exhaustion guards.

#### [MODIFY] [LCM-Rules-Cross-Reference.md](file:///D:/Git_Repositories/Workspace_AI/docs/LCM-Rules-Cross-Reference.md)
- Update Rule #1 (`ProposalReviewFlowPolicy.md`):
  - Expand rule identifiers to include `RULE-LCM-015` through `RULE-LCM-018`.
  - Add summary of new invariants to the Key Mandates column.

---

### Documentation Standards & Repository Implementation Specifications

#### [MODIFY] [Implementation.md](file:///D:/Git_Repositories/Workspace_AI/docs/Implementation.md)
- Append terminal section `## 5. Design Choices & Implementation Rationale` containing the structured trade-off analysis table defined in `CRP-2026-022`:
  - Defect Intake Gate (Mandatory `OPEN` state)
  - Activation Trigger Scope (Directional `PROCEED ALL` strictly above keyword)
  - Single-Item Activation (`PROCEED <Item/ID>`)
  - Runtime Bug Remediations (Autonomous exception for critical system transport)
  - Runaway Loop Protection (2-attempt loop breaker)
  - Batch Size Execution Guard (Credit/token exhaustion protection)

---

### Configuration Management Ledger

#### [MODIFY] [proposals.json](file:///D:/Git_Repositories/Workspace_Inventory/data/proposals/proposals.json)
- Update Proposal `#76` (`CRP-2026-022`):
  - Transition `state` from `suggested` to `approved` (or `in_progress`).
  - Set `plan_path` to `Workspace_Inventory/data/proposals/plans/Proposal-076_CRP-2026-022_Plan.md`.
  - Record transition history event.

#### [NEW] [Proposal-076_CRP-2026-022_Plan.md](file:///D:/Git_Repositories/Workspace_Inventory/data/proposals/plans/Proposal-076_CRP-2026-022_Plan.md)
- Archive the implementation plan into the permanent CM plan repository per `RULE-LCM-007`.

#### [MODIFY] [CRP-2026-022-LCM-v7.3.0-Bug-Crp-Intake-Proceed-Trigger-and-Batch-Bounds.md](file:///D:/Git_Repositories/Workspace_Inventory/docs/Proposals/CRP-2026-022-LCM-v7.3.0-Bug-Crp-Intake-Proceed-Trigger-and-Batch-Bounds.md)
- Update Status header from `OPEN` to `ACCEPTED`.

---

## Verification Plan

### Automated Checks
1. **Rule Discovery & Matrix Health**:
   - Run `pwsh -File "D:\Git_Repositories\Workspace_AI\tools\Test-WorkspaceReadiness.ps1"` to verify workspace health, rule discovery across junctions, and baseline integrity.
2. **JSON Schema & Syntax Validation**:
   - Verify `Workspace_Inventory/data/proposals/proposals.json` is valid JSON and conforms to the ledger schema.

### Manual Verification
1. **Visual Diff Inspection (Beyond Compare 5)**:
   - Run `pwsh -File "D:\Git_Repositories\Workspace_Inventory\tools\Invoke-BeyondCompareReview.ps1" Workspace_AI` and `Git_Repositories`.
2. **Review Receipt Gating**:
   - Verify audit receipts in `Workspace_Inventory/data/reviews/`.
