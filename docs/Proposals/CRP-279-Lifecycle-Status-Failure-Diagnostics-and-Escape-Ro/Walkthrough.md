# Walkthrough: CRP-279 - Lifecycle Status Failure Diagnostics and Escape Routes

## 1. Feasibility Assessment

Feasible. Existing lifecycle code already exposes the facts required for the
report:

- `Move-LcmProposalLifecycleState` has current and requested state plus
  transition authority.
- Cohort resolution identifies direct members, dependencies, synchronization,
  and BCR confirmation requirements.
- The review-obligation ledger identifies unresolved cross-repository gates.
- `Invoke-ProposalAction.ps1` is the common interactive lifecycle intent
  boundary.

## 2. Initial Design Decisions

No open design choice blocks the initial specification:

1. Return structured report data and render it for the console; do not replace
   existing nonzero lifecycle failure behavior.
2. Count only direct target failures. Dependencies are evidence, never
   separately counted failures.
3. Limit escape analysis to three ranked, non-executing routes and require an
   explicit later operator choice.

## 3. Implemented Behavior

- A recognized lifecycle refusal now carries a
  `lifecycle-status-failure` report object with direct failure records,
  source provenance, rule references, and at most three non-executing escape
  routes.
- The action dispatcher renders that report as a concise terminating error,
  preserving the failure exit behavior and allowing the existing Control Hub
  error display to surface it.
- Unexpected exceptions are not converted to lifecycle diagnostics.

## 4. Verification Evidence

- Focused lifecycle Pester tests cover report rendering, provenance,
  direct-target filtering, route limiting, and zero state mutation.
- PowerShell AST validation covers the shared module, action dispatcher, and
  lifecycle tests.
