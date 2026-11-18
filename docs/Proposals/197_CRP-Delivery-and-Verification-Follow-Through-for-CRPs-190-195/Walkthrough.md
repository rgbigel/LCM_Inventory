# Walkthrough: CRP-197

## Delivered Components

### Repository Index and Show-Repos

- Added `modules/RepositoryIndexManager.psm1` as the Inventory-owned source for
	read-only discovery of the workspace root and direct child Git repositories.
- `Get-RepositoryIndex` emits generated repository facts: name, absolute path,
	branch, short HEAD commit, and dirty state. It does not write to discovered
	repositories.
- An optional user-owned JSON overlay at
	`LCM_Inventory/data/repository-metadata.json` is merged by repository
	name only when present. Missing overlay files are accepted without mutation.
- Added `tools/Show-Repos.ps1` with table and `-AsJson` output modes.

### Compact Beyond Compare Review

- Added `modules/CompactBCompareReview.psm1` and
	`tools/Invoke-CompactBCompareReview.ps1`.
- The tool requires an explicit JSON inclusion manifest with an `include` array.
	Rooted and parent-traversal paths are rejected.
- Selected content is projected only into unique scratch-session roots:
	`Baseline/<RepositoryName>/<repository-relative-path>` and
	`Working/<RepositoryName>/<repository-relative-path>`.
- The baseline is read from the requested local Git commit and the working
	content is copied from the live repository. The source repository is neither
	staged nor modified. Optional launch opens both panes read-only and uses the
	interactive-desktop dispatcher when it is available.

### Same-Repository Stale BCompare Windows

- Added `modules/BCompareWindowTools.psm1` with
	`Get-SameRepositoryBCompareProcess` and `Remove-StaleBCompareProcess`.
- `Invoke-BeyondCompareReview.ps1` now delegates title selection and process
	termination to that module, retaining the existing repository-name plus
	`<-->` title-match behavior while leaving unrelated BCompare windows alone.

## Verification Evidence

Executed on 2026-10-13:

```text
Invoke-Pester RepositoryIndexManager.Tests.ps1,
							BCompareWindowTools.Tests.ps1,
							CompactBCompareReview.Tests.ps1

Tests Passed: 7, Failed: 0, Skipped: 0
```

The compact-review projection test initializes an isolated temporary Git
repository, modifies its live working file after committing the baseline, then
verifies that scratch `Baseline/tools/example.ps1` contains the committed
content, scratch `Working/tools/example.ps1` contains the changed content, and
the live working file remains unchanged.

PowerShell AST parsing also passed for all six production files added or
modified by this CRP. CRP-196 files were not changed.