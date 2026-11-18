# Walkthrough: CRP-346 - BCR Window Ownership And Tab Refresh Instead Of Relaunch

Date: 2026-11-18 14:32:27

## 1. Path taken and issues on the way
- Sequence (operator option C): CRP-345 first (tab atom), then this CRP; rule texts drafted, not applied (option B).
- Choices made without the operator:
  - The drive letter is the window-identity check (record holds the mounted drive); the compare roots inside BC are not read, because BC exposes neither tab names nor path texts reliably. A remount to another drive letter launches a new window.
  - Adoption of one unrecorded `_LCM` window covers windows started before this CRP; it only works while that window's active tab is `_LCM` (title search). With a record, the active tab does not matter.
  - A bare `bcr` no longer asks for confirmation (R5); the repository scope keeps its limits.
  - R1 skips the origin repository of a completed item: its changes belong to a new revision.
- Operator finding at Gate 2 (2026-11-18): the atom sent F5 (BC "Refresh", fast); the review needs "Full Refresh". BC's Edit menu (screenshot of a Claude-owned `/solo` window) shows Refresh = F5, Full Refresh = Ctrl+F5; the atom now sends Ctrl+F5 (`Select-BeyondCompareTab.ahk` 10.7.5).
- Full Refresh test 14:54 (attempt 1) failed: the atom could not bring the window to the front within 5 s (Windows foreground lock; window not minimized), and the code treated that like "no `_LCM` tab" and launched a second window (PID 34196, closed again by Claude). Fixes: the atom retries the activation three times (restoring a minimized window) and reports a refusal with its own exit code 4; BCR launches a new window only on exit code 3 (no `_LCM` tab); any other failure writes a warning asking the operator to press Ctrl+F5, without a launch.
- Attempt 2, 14:55:20: Full Refresh (Ctrl+F5) sent to the operator's window (PID 40376, adopted because the record pointed to the closed PID 34196); no new window.
- Untested paths: the fresh-mount path (remount of a newer image followed by refresh) runs at the next new image; the "no `_LCM` tab -> launch" path; adopting when two `_LCM` windows are open (then a new window is launched and recorded).

## 2. Verification evidence (2026-11-18 14:32:27)
- Parse gate: `Invoke-MacriumDailyBcrBaseline.ps1`, `ProposalManager.psm1`, `Invoke-ProposalAction.ps1`, test files 0 errors.
- Tests: `ProposalCompletion` 7/7 (incl. R1), `ProposalScaffold` 5/5, `LcmAhkAtoms` 7/7; `ProposalLifecycle` 47 passed, 3 failed (the same 3 pre-existing module failures as before, BUG-348 candidates); the updated computed-cohort case passes.
- Live, 14:30:18 (`Invoke-MacriumDailyBcrBaseline.ps1 -ReviewScope CRP-346`, today's image already on F:): the operator's window (PID 40376) was adopted, the atom found the `_LCM` tab and sent F5, only that window got the tag `[CRP-346]`, no new window opened; `Launched: False`, `ReusedExistingReviewWindow: True`; record written.