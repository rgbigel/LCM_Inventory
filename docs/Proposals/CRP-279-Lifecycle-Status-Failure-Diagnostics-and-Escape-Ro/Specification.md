# Change Request Proposal: CRP-279

`yaml
CRP-ID: CRP-279
Title: Lifecycle Status Failure Diagnostics and Escape Routes
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-15 17:49:31
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
`

---

## 1. Executive Summary & Intent
Generate an evidence-backed failure report whenever a user-requested lifecycle
status change for a BUG, CRP, or cohort cannot be applied. The report makes
the exact failure and its remedy understandable without treating indirect
dependencies as independent failures.

## 2. Technical Requirements & Invariants

### 2.1 Trigger and Scope

- Generate the report when an intent to change lifecycle status fails in
  `Invoke-ProposalAction.ps1`, a Control Hub dispatch path, or a shared
  lifecycle helper.
- Preserve the original action, target expression, requested target state,
  and execution time.
- Report only CRP/BUG/cohort identities that directly fail the requested
  operation. A dependent CRP must appear only as evidence or a blocking
  dependency, not as another failed target.
- Preserve atomicity: a failed multi-target operation must report every
  directly failing target and must not report a success-shaped partial result.

### 2.2 Per-Target Failure Record

For each directly failing target, the report must contain:

1. The identity, current status, requested action/status, and extent of
   failure.
2. A plain-language reason and the concrete discrepancy between requested
   intent and current governed state.
3. Every involved repository.
4. The relevant implementation source by repository-relative path and symbol,
   when code determined the outcome.
5. The governing rule and documentation references by identifier and
   repository-relative location when they conflict with the requested action.
6. A conflict type selected from: invalid transition, incomplete evidence,
   unresolved review obligation, cohort membership or gate conflict,
   authorization requirement, target-resolution failure, or implementation
   defect.
7. A recommended operator remedy with a clear precondition and expected
   effect.

If a required fact cannot be resolved, the report must state that explicitly,
identify the unavailable evidence, and must not infer a cause.

### 2.3 Escape Routes

- Analyze feasible governed escape paths after recording the failure.
- Present at most three routes, ranked by least disruptive compliant remedy.
- Every route must identify the required user action, affected identities, and
  whether it changes status, scope, or review evidence.
- Never execute an escape route, mutate lifecycle state, or broaden a target
  merely by generating the report.
- When no compliant escape route exists, say so plainly and recommend the
  smallest next diagnostic action.

### 2.4 Presentation and Persistence

- Return a structured report object for callers and a concise readable
  rendering for interactive use.
- Persist a durable receipt only when the existing lifecycle evidence model
  provides an applicable receipt location; the receipt must be separate from
  accepted-review and commit authorization evidence.
- Do not emit raw exception stacks as the operator-facing report. Preserve
  structured diagnostic evidence for troubleshooting without concealing the
  original failure.

### 2.5 Compatibility and Governance

- Preserve all existing valid lifecycle transitions, BCR gates, cohort
  synchronization, and commit authorization behavior.
- Follow `RULE-LCM-014` by requiring an explicit operator choice before
  proceeding beyond a failed lifecycle gate.
- Follow `RULE-LCM-023` by accurately reflecting minimal-test state when that
  state contributes to a failure.
- Follow `RULE-LCM-024` by identifying missing verification evidence rather
  than assuming it exists.

## 3. Acceptance Criteria

- A failed single-CRP transition produces one direct failure record with
  source and rule/documentation provenance where available.
- A failed cohort operation distinguishes its directly failing members from
  indirect dependents and reports all direct failures atomically.
- An unresolved cross-repository BCR obligation identifies the blocking
  repository and obligation without labeling that repository as an
  independently failed CRP.
- The report emits no more than three escape routes and executes none.
- Existing Pester lifecycle tests remain valid, with focused tests for the
  report's direct-target filtering, provenance, conflict classification, and
  route limit.
