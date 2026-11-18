# Walkthrough: CRP-346 - BCR Window Ownership And Tab Refresh Instead Of Relaunch

Date: 2026-11-18 21:29:36

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
## 3. Revision 2026-11-18: rule texts applied (operator instruction "crp 346")
- Reinstated with changes (completed -> in_progress). Section 5 texts applied to `LCM_AI/.agents/rules`: ProposalReviewFlowPolicy.md 10.3.2 -> 10.3.3 (RULE-LCM-002 implied cohort, RULE-LCM-016 two COMPLETE bullets), ReviewCommitGovernancePolicy.md 10.3.1 -> 10.3.2 (RULE-REV-012 items 2 and 4), macro-definitions.md 10.3.1 -> 10.3.2 (BCR bullets 2 and 4, COMPLETE bullet).
- Choice made without the operator: in RULE-REV-012 item 2 the second clause ("MUST NOT poll window titles ... or kill instances ...") is kept; only the tagging part is replaced. Item 4 also names the Full Refresh found at Gate 2.
- Claude adapter (`.claude/rules/process`) updated in the same change set (RULE-AUTH-002): the three projections, their `Source:` lines, and `translation/CANONICAL_HASHES.md` (new SHA-256 prefixes 0ABF03F4C231F660, 4768FB9A0A7F9BFE, FE2766E193711B03, history line).
- `AGENTS.md` and `LCM_AI/docs/LCM-Rules-Cross-Reference.md` list rules by file and ID range only; no IDs changed, no update needed. `Test-LCMRuleHealth.ps1`: all repositories in compliance.
- The COMPLETE macro bullet "automatically closes matching Beyond Compare review window" remains (observation in Specification section 5, not part of the texts).
- Commit requires ADMINMODE (rule paths staged).

## Revision: review window record never matched (2026-11-18 21:29:36)

- Found while refreshing BCR for CRP-354: your window 40376 had a Text Compare tab in front and BCR launched a second window (PID 28876); I closed nothing.
- Cause: `ConvertFrom-Json` returns the recorded `StartTime` as a DateTime, `[string]` cut it to seconds, so the record comparison was never true; reuse only worked through the fallback "exactly one window whose active tab is _LCM".
- Fix: `Test-LcmSameProcessStart` compares both as instants (UTC, 1 ms) (`tools/Invoke-MacriumDailyBcrBaseline.ps1` 10.2.8 -> 10.2.9).
- Also: `tests/MacriumBcrReview.Tests.ps1` still asserted four texts that the CRP-346 change of the morning had replaced (it failed since commit cb45b81, unnoticed in my report); updated to the current code.

| Check                                        | Result                           |
|:---------------------------------------------|:---------------------------------|
| Parse gate (tool, tests)                     | 0 errors                         |
| `BcrReviewWindowRecord.Tests.ps1` (new)      | 3/3                              |
| `MacriumBcrReview.Tests.ps1`                 | 15/15                            |
| Live: record of PID 28876 vs its start time  | match                            |
