# Walkthrough: BUG-351 - Review Completion Flow And Proposal Registration Defects

Date: 2026-11-18 12:20:46

## 1. Path taken and issues on the way
- Registration of this BUG: the governed action could not create items (the defect T3 fixes), so BUG-351 was created directly with `New-LCM_Proposal -CrId 'BUG-'`, the way earlier BUGs were made. BUG-352 was later created through the fixed action.
- Design choice made without the operator: obligations are registered at completion time from the live changes, not when the BCR cohort is formed (operator remark 2.3 placed it at cohort generation). Reason: the `do` / `proceed` continuation opens one BCR per open obligation; registered at BCR launch, every repository would get its own BC window. Reject at Gate 2 if the cohort-time variant is wanted.
- Testing without real commits: the completion function calls the commit tool, which really commits. To test the order of calls, the tool path is a script variable; the test replaces it with a stub script that only writes the repository name to a log. The ledger functions are replaced by in-memory stand-ins in the same way. This seam exists only for testing.
- Scope split at Gate 2: Tool Explorer items moved to BUG-352 (operator ACCEPT 2026-11-18).
- This completion also commits other open working-tree paths of the governed repositories: the CRP-346 section 4 amendment and the session files in `LCM_AI/.agents`. BCR compares against the Macrium image, so the CRP-346 specification review is unaffected.

## 2. Verification evidence (2026-11-18)
- Parse gate (`Parser::ParseInput`): `Invoke-ProposalAction.ps1` 0 errors, `Submit-ReviewResult.ps1` 0 errors; CRLF, no lone LF.
- `Invoke-Pester tests/ProposalCompletion.Tests.ps1, tests/ProposalLifecycle.Tests.ps1`: 53 passed, 3 failed.
  - New tests 6/6: excluded paths ignored; secondary repositories first and origin last; last changed repository as primary when the origin is unchanged; single-repository path when nothing changed; merged finding in ledger and Specification; merge refused for a non-BUG.
  - The 3 failures are pre-existing: they test only `ProposalManager.psm1`, unchanged with its test file since `58ad671` (2026-11-15): transition matrix, missing `logs/history/cm_activity_v5_v6_history.log`, hold field `blocked` vs `held`. Candidate for BUG-348.
- Live: `bug 351` moved BUG-351 to `in_progress`; `bug -Title ... -Details ...` created BUG-352; ledger parity `Sync-LcmProposalsDb.ps1 -Action Verify` PASS.
- Side effect of the test run: the existing real-script case (`complete COH-999999`) re-renders `data/artifacts/CM_CONTROL_HUB.html`.
