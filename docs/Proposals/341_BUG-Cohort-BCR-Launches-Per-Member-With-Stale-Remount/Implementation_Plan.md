# Implementation Plan: BUG-341 - Cohort BCR Launches Per Member With Stale Remount

## 1. Executive Summary & Problem Context
Invoke-ProposalAction -Action bcr COH-331 (6 members) ran one BCR per member instead of one joint cohort BCR (RULE-LCM-002): 6 remounts of the same 07-07 image and 6 Beyond Compare windows within 6 min. Staleness check compares snapshotSaved 2026-11-14 22:37:12 instead of the mounted image date, so F: is always stale (RULE-REV-012). Members were not moved to in_review.

Corrected cause (2026-11-17): the decision uses the newest internal log inside the image, not `snapshotSaved` (see Specification section 1).

## 2. Gate 0 Traceability
- Map each implementation component and verification activity to the accepted Gate 0 target-state clause.

| Component | Gate 0 clause |
|:---|:---|
| C1 one joint launch per declared cohort | Target State 1; Invariants 1-2 |
| C2 image-identity currency check | Target State 2; Invariant 3 |
| C3 contract tests | Exit criteria |

## 3. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for Cohort BCR Launches Per Member With Stale Remount.

### Component C1: `tools/Invoke-ProposalAction.ps1` (10.2.1 -> 10.2.2)
- In the `bcr` branch: when `$resolution.DeclaredCohortId` is set, only the first `Invoke-MacriumBcrReview.ps1` call launches; all further members (review-ready and already-in-review) run with `-NoLaunch` and only record their metadata. Non-cohort behaviour unchanged.

### Component C2: `tools/Invoke-MacriumDailyBcrBaseline.ps1` (10.2.6 -> 10.2.7)
- Before the log-date heuristic: if registry `MRMImagePath` equals today's completed image and `MRMdrive` equals the candidate drive, the mounted baseline is current (fast path). The log-date heuristic stays as fallback. Caveat recorded in `.NOTES`.

### Component C3: `tests/MacriumBcrReview.Tests.ps1` (10.2.1 -> 10.2.2)
- Two static contract tests: identity check precedes the heuristic; one joint launch per declared cohort.

## 4. Verification Plan
- Automated Pester tests and readiness quality gates.
- Parse gate on the three scripts; `MacriumBcrReview.Tests.ps1`; `ProposalLifecycle.Tests.ps1` with a live-ledger hash guard (BUG-336 lesson).
- Live (Gate 2): add BUG-341 to COH-331, one `bcr COH-331`; expected one mount of today's image and one BC window; the `Invoke-MacriumDailyBcrBaseline-*.log` series shows the fast-path line for members 2..n.
