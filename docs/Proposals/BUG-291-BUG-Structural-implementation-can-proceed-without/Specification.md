# Bug Proposal: BUG-291

Module: docs/Proposals/BUG-291-BUG-Structural-implementation-can-proceed-without/Specification.md
Purpose: Define the corrective guard for proposal-first governance bypasses.
Path: D:\Git_Repositories\LCM_Inventory\docs\Proposals\BUG-291-BUG-Structural-implementation-can-proceed-without\Specification.md
Authors: Rolf, Copilot
Version: 1.0.1
Status: Completed
Date: 2026-10-18

```yaml
BUG-ID: BUG-291
Title: Structural implementation can proceed without a proposal-first Gate 1 record
Scope: LCM_Inventory lifecycle/readiness/commit enforcement
Trigger: OneDriveMaintenance was created and implemented before CRP-290 existed
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
```

## 1. Defect

The current governance toolchain permits structural repository creation and implementation to reach operator review without proving that an originating CRP existed and passed Gate 1 first. Existing `Assert-LcmImplementationAllowed` protects only analysis-mode state; it does not require a proposal identity or a Gate-1 lifecycle state.

## 2. Target State

Common lifecycle enforcement rejects a structural implementation, review-readiness, or commit-readiness request when its governed repository lacks an originating proposal that has passed Gate 1. The rejection must identify the repository, the missing or ineligible proposal state, and the exact corrective action.

## 3. Requirements and Invariants

1. Add one reusable proposal-first assertion rather than separate, inconsistent checks.
2. The assertion accepts an explicit repository and proposal identity and verifies:
   - the proposal exists;
   - its `origin_repo` matches the repository;
   - its lifecycle state is eligible for implementation (`in_progress`, `verified`, or `in_review`), not merely `suggested`;
   - a proposal bundle with a specification exists.
3. Integrate the assertion into the authoritative implementation/readiness/commit path, including the official new-App or repository-scaffolding path where applicable.
4. The guard must not retroactively reject read-only inspection, proposal drafting, or historical completed records.
5. Failure output must be explicit and actionable; silent fallback, inferred proposal selection, and `-Force` bypass are prohibited.
6. Add focused Pester coverage for missing, mismatched, suggested, and eligible proposal states.
7. Update directly related lifecycle documentation and script metadata.

## 4. Explicit Non-Goals

- Rewriting historical repositories or deleting existing work.
- Treating CRP-290 as accepted automatically.
- Replacing the required BCR/commit review gate.
- Blocking analysis-only or proposal-authoring operations.

## 5. Acceptance Criteria

- A test proves an unproposed repository cannot pass the affected implementation/readiness/commit gate.
- A test proves a `suggested` CRP cannot authorize implementation.
- A test proves an `in_progress` proposal with matching origin and specification bundle can authorize the protected operation.
- The resulting failure tells the operator to create or accept the relevant proposal; it does not recommend a bypass.

## 6. Completion Control

BUG-291 closes only when the Implementation Plan remediation is implemented, the acceptance criteria have objective evidence, the required BCR result is recorded, and the accepted scope is committed. The completed walkthrough is the evidence record for that closure; future changes to the guard require a new proposal or linked regression, not an append to this completed BUG walkthrough.
