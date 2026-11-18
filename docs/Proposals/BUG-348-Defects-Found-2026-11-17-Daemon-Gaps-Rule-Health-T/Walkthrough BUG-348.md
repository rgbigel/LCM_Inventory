# Walkthrough: BUG-348 - Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks

Date: 2026-11-18 15:57:30

## 1. Path taken and issues on the way
- The push dry-run defect was larger than reported: besides the unguarded second maintenance call, the Update-Gemini step and the tool-catalog step also commit during a dry run. All three are now skipped.
- Merged item b is not fixed: `.agents/ACTIVE_SESSION.md` records decision D-31 (held): bundles are not purged at push until their content is absorbed. The 130 remaining pushed bundles are intended.
- Decision for the operator (item 4, third failure): the module allows 10 lifecycle transitions that the authoritative state table (ProposalReviewFlowPolicy) and the test forbid: rejected -> suggested / in_progress, withdrawn -> suggested / in_progress, verified -> completed, in_progress -> in_review / completed, in_review -> verified, held -> superseded, completed -> in_progress. The last one is the `reinstate -Changes` path, which the rule allows, so the test table lacks it. Tightening the others changes engine behaviour; not done without the operator.
- The first rule-health patch left a missing line break (parse error, file briefly unparsable); repaired in the next call and parsed clean.
- Segment 2 is deferred: rebuilding and redeploying the daemon while the operator is away could leave the Control Hub broken.

## 2. Verification evidence (2026-11-18 15:57:30)
- Parse gate: `Invoke-LCM_Push.ps1`, `Test-LCMRuleHealth.ps1`, `ProposalManager.psm1`, `ProposalLifecycle.Tests.ps1` 0 errors.
- `Test-LCMRuleHealth.ps1`: every repository "In Compliance" ("All repositories are in full compliance").
- `ProposalLifecycle.Tests.ps1`: 49 passed, 1 failed (the transition-table decision above).
- Not yet run: a full push dry run (it would need the learned-advice review first); the Maintenance button in the browser.