# Walkthrough: BUG-207

## Discovery

While completing CRP-206, the command reported completion at existing commit
`2b1c4cd` even though CRP-206 files remained uncommitted. Its receipt contained
no staged actions and cleanup purged a stale BUG-200 scratch directory.

## Repair

`Submit-ReviewResult.ps1` now requires a current staging manifest that matches
the target repository and current baseline, and requires at least one approved
action unless an explicit complete-all disposition is used. It verifies a real
staged Git diff before committing. Receipts, manifest deletion, scratch purge,
and proposal synchronization occur only after a new commit succeeds.

## Validation

`BCompareReviewLifecycle.Tests.ps1` passed 9 of 9 tests. A runtime probe
against an isolated Git repository without a staging manifest failed as
required and created no review receipt.
