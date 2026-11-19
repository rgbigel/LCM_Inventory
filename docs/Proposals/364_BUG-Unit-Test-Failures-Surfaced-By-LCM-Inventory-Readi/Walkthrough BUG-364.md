# Walkthrough: BUG-364 - Unit Test Failures Surfaced By LCM_Inventory Readiness Gate

Module: docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Walkthrough BUG-364.md  
Purpose: Path taken and test evidence.  
Path: LCM_Inventory/docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Walkthrough BUG-364.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 11:05:00

---

## 1. Cases and Causes (2026-11-19)

| Cases | File | Cause | Change |
|:---|:---|:---|:---|
| 3 | ContextAbsorption | `Absorb-LcmContextRemark.ps1`, `Link-LcmLearnedAdvice.ps1` resolved the LCM_Inventory-relative `bundle_dir` against the workspace root; the resolver then fell back to the new document name, absent in legacy bundles | tools: resolve the bundle folder (workspace root, else LCM_Inventory) before the document name |
| 5 | ControlHubSafety | expectations behind operator-accepted template commits (1452779 2026-11-09, 75c6d5c 2026-11-12, 40c75f0 2026-11-14): endpoint `/api/action` (same daemon handler as `/execute`), `-Pane` on `Open-LcmStandardDisplay`, `options: { sync, noExit }`, Proceed via the ITEM selector, open rail without the prio 0 exclusion; BUG-276 now `pushed` | test expectations updated; live-ledger check accepts completed or pushed |
| 3 | FailureModeAnalysis, ShowFailureAnalysis | hard-coded version 10.0.1; tools read their headers (10.2.1) | tests read the expected versions through `Get-LcmDisplaySourceVersion` / `Get-LcmDisplayProvenance` |
| 1 | FailureModeAnalysis | test picked the first `completed` item of the live ledger; none after the push | accepts `completed` or `pushed` (`do` is invalid in both) |
| 1 | LcmStandardDisplay | fast path now posts to the DO daemon `/open` (RULE-PS-011); the test mocked only `Start-Process`, so every run opened a live browser tab | `Invoke-RestMethod` mocked; asserts the `/open` call with the unchanged URL and no `Start-Process` |
| 1 | ProposalSpecificationState | test used `LCM_AI` as bundle owner; since e6b4630 (2026-11-14, RULE-LCM-034) LCM_* bundles live only in LCM_Inventory | cross-repository case uses the disjunct subsystem `HaSSD06` (RULE-SUB-008) |
| 5 | only inside the gate | the gate's StrictMode, error preference and imported modules leaked into the tests | `Test-RepoReadiness.ps1` runs the suite in a background job (clean process) |
| 1 | ProposalLifecycle | matrix contradiction module / test / rule | open: operator decision (Specification section 3) |

- Noise, not a failure: `ProposalSpecificationState.Tests.ps1` locks a Specification on purpose and expects the "rollback failed ... used by another process" error.
- Observed: full runs write live files (catalog, `DoT` trampolines, `CM_CONTROL_HUB.html`, `active_session.json`, `proposals.db`); `proposals.db` content verified equal to the 00:02 dump.

## 2. Evidence

| Check | Result |
|:---|:---|
| `ParseFile` of every changed `.ps1` (2 tools, 6 tests, readiness gate) | 0 errors |
| ContextAbsorption / ControlHubSafety / FailureModeAnalysis / ShowFailureAnalysis / LcmStandardDisplay / ProposalSpecificationState on their own | 6/6, 11/11, 28/28, 6/6, 4/4, 9/9 |
| `LEARNED_ADVICE.md`, `ACTIVE_CONTEXT.md`, bundles 311/312 after ContextAbsorption | unchanged (timestamps 2026-11-18 23:58:53 / 2026-11-10) |
| Full run, clean session | 362 total, 1 failed (lifecycle matrix) |
| `Test-RepoReadiness.ps1` full (gate) before / after the clean-process change | 6 failed / 1 failed (lifecycle matrix) |
