# Implementation Plan: CRP-357 - Single Complete-Review Tool With Review Completion Atoms

Date: 2026-11-18 23:22:39

- Segment 1 (done): `tools/Complete-Review.ps1` (new), `modules/LcmReviewCompletionAtoms.psm1` 10.7.5, `tools/Invoke-ProposalAction.ps1` 10.2.7, `tools/Complete-ReviewCohort.ps1` (shim), `tools/Submit-ReviewResult.ps1` 10.2.6 (version in log line), `tests/ProposalCompletion.Tests.ps1`; catalog intent `complete-review`.
- Segment 2 (open, Specification T4): move the per-repository commit body into the atoms module; retire the old scripts one release later.
