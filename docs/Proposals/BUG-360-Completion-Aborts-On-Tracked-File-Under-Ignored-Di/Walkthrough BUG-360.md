# Walkthrough: BUG-360 - Completion Aborts On Tracked File Under Ignored Directory

Date: 2026-11-18 18:35:11

## 1. Path taken
- Found while completing CRP-346 (operator Gate 2 for CRP-344/346, BUG-352, CRP-355/359, 2026-11-18): the root repository was committed (`d49cb27`), then LCM_AI aborted on `docs/Logs/03_Propagation-and-Continuous-History/Major_Version_Milestone_Rollup.md`. Cause: LCM_AI `.gitignore` line 9 `logs/` matches `docs/Logs` case-insensitively; `git add -A -- <path>` staged the tracked file and exited 1.
- Fix: after a non-zero exit, the path counts as staged when it is tracked and has no unstaged change left; otherwise the old error.
- Gate 2 exception (RULE-REV-001 (2), flow-impeding BUG, attempt 1 of 2): the fix rides in the LCM_Inventory commit of the CRP-346 completion, because the completion cannot proceed without it; the operator's visual review of this change happens with the next BCR. Syntax gate and tests are not waived.
- Side effect recorded: root commit `d49cb27` carries the CRP-355 rollup change under the CRP-346 message (root `docs` is a junction to `LCM_AI\docs`, both repositories track the file).

## 2. Verification evidence (2026-11-18 18:35:11)
- Parse gate: `Submit-ReviewResult.ps1`, test file 0 errors.
- `Invoke-Pester tests/ReviewStagingIgnoredDirectory.Tests.ps1`: 3/3 (tracked file staged despite exit 1; untracked ignored file not staged; tolerance present only for the tracked case).
- Integration: the resumed CRP-346 completion (see ledger history of CRP-346).