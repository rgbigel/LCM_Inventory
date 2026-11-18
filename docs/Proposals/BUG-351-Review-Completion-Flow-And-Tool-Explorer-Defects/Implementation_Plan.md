# Implementation Plan: BUG-351 - Review Completion Flow And Proposal Registration Defects

Date: 2026-11-18 12:20:46

## 1. Changes per file

### `tools/Invoke-ProposalAction.ps1` (10.2.2 -> 10.2.3)
- New `Get-LcmChangedGovernedRepositories`: for each governed repository, lists modified, staged and untracked paths and keeps those that are not excluded from commits (`data/`, `logs/`, `scratch/`, ... - same exclusion as the commit tool). Returns the repositories with at least one such path. (T1)
- New `Invoke-LcmItemReviewCompletion` replaces the direct call of `Submit-ReviewResult.ps1` at the three completion points (`complete`, `proceed` to completed, Gate 2 `accept`). (T1)
  - Primary repository = the item's origin repository if it changed, else the last changed one.
  - Every other changed repository (plus any still-open obligation) is first registered as a cross-repository review obligation, then committed.
  - The primary repository is committed last; only this call moves the item to `completed`.
  - Nothing changed -> unchanged single-repository behaviour.
- New branch for `bug` / `suggest`: no target -> `New-LCM_Proposal` (needs `-Title`, BUG via `-CrId 'BUG-'`); `bug <BUG-ID> -Details` -> new `Add-LcmBugMergedFinding` appends `[merged <ts>] <text>` to the ledger details and to `## Merged Findings` in the BUG's Specification; a BUG still `suggested` then starts DOIT as before. (T3)
- The path of the commit tool is held in `$script:LcmSubmitReviewResultPath` so a test can replace it (see Walkthrough).

### `tools/Submit-ReviewResult.ps1` (10.2.2 -> 10.2.3)
- Missing `-RepositoryPath` throws with a pointer to `COMPLETE` instead of using the workspace root; help text updated. (T2)

### `tests/ProposalCompletion.Tests.ps1` (new)
- 6 tests for T1 and T3 (below).

## 2. Order of commits for an item changing root, `LCM_AI` and `LCM_Inventory` (origin)

| Step | Repository | Effect |
|:---|:---|:---|
| 1 | `Git_Repositories` | obligation registered, committed, obligation resolved |
| 2 | `LCM_AI` | same |
| 3 | `LCM_Inventory` | committed, item `completed` |
