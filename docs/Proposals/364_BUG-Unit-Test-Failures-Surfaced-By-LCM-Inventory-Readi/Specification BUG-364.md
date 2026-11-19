# Specification: BUG-364

Module: docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Specification BUG-364.md  
Purpose: Unit Test Failures Surfaced By LCM_Inventory Readiness Gate  
Path: LCM_Inventory/docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Specification BUG-364.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 11:05:00

```yaml
CRP-ID: BUG-364
Title: Unit Test Failures Surfaced By LCM_Inventory Readiness Gate
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 11:05:00
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 5
App-ID: None
Severity: Medium
Affected-Repos: LCM_Inventory
Root-Cause: tests behind operator-accepted behaviour (versions, template, endpoints, LCM_* bundle centralization), tests bound to the live ledger state, two tools resolving bundle_dir against the workspace root, readiness gate leaking its session state into the tests; one lifecycle matrix contradiction (module / test / rule)
```

---

## 1. Executive Summary & Intent

- The new LCM_Inventory readiness gate (CRP-343, 2026-11-19) runs all `tests/*.Tests.ps1`; 15 to 19 of 362 cases failed. Operator 2026-11-19: work through them.
- Result: 361 of 362 pass in a clean run; the remaining case (lifecycle transition matrix) needs an operator decision (section 3).
- Review: this Specification; the Walkthrough holds the evidence per case.

## 2. Gate 0 Contract

### Target State

T1 Every failing case is either fixed at its cause (tool or test) or presented to the operator as a decision.

T2 Tests follow operator-accepted behaviour; they read versions from the source headers and do not depend on the daily ledger state.

T3 No test opens a live browser tab or writes outside its test drive through the desktop fast path.

T4 The readiness gate runs the unit tests in a clean process.

### Invariants and Exit Criteria

- Accepted behaviour is not changed to satisfy a stale test; a removed pattern counts as accepted only when the removing commit is an operator-accepted one.
- Every changed file passes the syntax gate; each affected test file passes on its own and in the full run.
- Exit: full run in the gate 361/362 with only the decision case open, then the decided state.

### Explicit Non-Goals

- No change to the lifecycle matrix without the operator's decision.
- No refactoring of the tests beyond the failing assertions.
- Default: cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Open Item: Lifecycle Transition Matrix (operator decision)

`Test-LcmProposalLifecycleTransition` (ProposalManager.psm1) allows 10 transitions the test forbids; the authoritative table (ProposalReviewFlowPolicy, CRP-261) differs from both:

| Transition | Module | Test | Rule table |
|:---|:---|:---|:---|
| withdrawn -> suggested / in_progress | allowed | forbidden | terminal (view) |
| rejected -> suggested / in_progress | allowed | forbidden | terminal (view) |
| held -> superseded | allowed | forbidden | held: continue / edit / withdraw |
| in_review -> verified | allowed | forbidden | not listed |
| completed -> in_progress | allowed | forbidden | via `reinstate -Changes` |
| in_progress -> in_review / completed; verified -> completed | allowed | forbidden | "direct Gate 2 acceptance auto-promotes through verified -> in_review" |
| withdrawn / rejected -> superseded | forbidden | allowed | terminal (view) |

Options: A module follows the rule table (test adjusted to the table); B the rule table is extended to the module's behaviour (rule change, ADMINMODE, RULE-AUTH-002); C case by case.
