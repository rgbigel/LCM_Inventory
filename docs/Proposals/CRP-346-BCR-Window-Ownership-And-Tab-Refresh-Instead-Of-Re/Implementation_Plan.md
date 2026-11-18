# Implementation Plan: CRP-346 - BCR Window Ownership And Tab Refresh Instead Of Relaunch

Date: 2026-11-18 14:32:27

## Changes per file
- `tools/Invoke-MacriumDailyBcrBaseline.ps1` (10.2.7 -> 10.2.8): new `Save-LcmReviewWindowRecord`, `Find-LcmReusableReviewWindow`, `Invoke-LcmReviewWindowRefresh`, `Open-LcmReviewWindow`; both launch points (mounted-baseline fast path and fresh mount) call `Open-LcmReviewWindow`.
  - Record `scratch/BC_Review/review-window.json`: process ID, process start time, window handle, mounted drive, review scope.
  - Reuse: the recorded window if its process (same ID and start time) is alive and it compares the same drive; without a record, exactly one window whose active tab is `_LCM` is adopted (windows started before this CRP).
  - Reuse refreshes the `_LCM` tab with the CRP-345 atom (`select-beyondcomparetab refresh _LCM`) and tags that window; no `_LCM` tab or no reusable window -> launch `/solo _LCM`, identify the new window as the BCompare process that did not exist before, record and tag it.
- `modules/ProposalManager.psm1` (10.2.5 -> 10.2.6), `Get-LcmReviewCohortResolution`: implied scopes (`computed`, `repository`) keep only `verified` / `in_review` members; `in_progress` items are returned as `NotReady`; a computed scope needs no selection or confirmation.
- `tools/Invoke-ProposalAction.ps1` (10.2.3 -> 10.2.4): `bcr` prints each `NotReady` item with the choices do / ride as WIP / hold; `Invoke-LcmItemReviewCompletion` on a `completed` item commits the remaining governed repositories as obligations, skips the origin repository with a notice, and leaves the lifecycle unchanged.
- Tests: `tests/ProposalLifecycle.Tests.ps1` (computed-cohort case updated to R2/R5), `tests/ProposalCompletion.Tests.ps1` (+1 case for R1).
- Rule texts: Specification section 5 (applied by the operator or Antigravity).