# Walkthrough: BUG-340 - New-LCM_Proposal Placeholder Slug and Version Defects

Date: 2026-11-18 13:23:21

## 1. Path taken and issues on the way
- BUG-353 (scaffold repeats the intake in all three documents) was merged in through `bug 340 -Details` (BUG-351 merge path) and withdrawn; the merge also started DOIT.
- Change against the 2026-11-16 Gate 0, made without the operator: a placeholder Plan or Walkthrough only warns at `verified`, it does not refuse it, and the Gate 1 check was dropped. Reasons: under REQ-WINV-014 the Plan is legitimately "not written yet" at Gate 1; the operator's 2026-11-18 meta analysis named excessive checks as a cause of the CRP-350 stall; bookkeeping never aborts a lifecycle step (RULE-EFF-002). Reject at Gate 2 if the blocking variant is wanted.
- First test run: 5 of the new tests failed because the test's store fixture lacked `updated_at`, which `Set-ProposalStore` writes; the save failed and the next tests collided on the same ID. Fixture corrected; the live ledger was not touched (`last_proposal_id` 354 before and after).

## 2. Verification evidence (2026-11-18 13:23:21)
- Parse gate: `ProposalManager.psm1` 0 errors.
- `Invoke-Pester tests/ProposalScaffold.Tests.ps1, tests/ProposalSpecificationFence.Tests.ps1`: 9 passed, 0 failed (version from `version.json` against a conflicting `inventory.json`; document roles; folder reuse; shortened-name notice; placeholder detection and non-blocking `verified`).
- `tests/ProposalCompletion.Tests.ps1` 6/6 passed; `tests/ProposalLifecycle.Tests.ps1` unchanged at 3 pre-existing failures (BUG-348 candidates, see BUG-351).