# Implementation Plan: CRP-199

## Changes

1. Update `Invoke-BeyondCompareReview.ps1` so its staging audit records only
   explicit BCompare selections and does not derive candidates from raw bytes.
   `System.IO.FileInfo` instances.
2. Normalize the per-CRP live-junction name to `Live_<RepositoryName>` and
   restrict stale-junction cleanup to that exact name.
3. Update `Submit-ReviewResult.ps1` to load `.lcm_review.json`, derive the
   CRP review directory, remove its junction nodes non-recursively, and then
   purge the CRP directory after a successful review commit.
4. Add focused Pester contracts for the audit collection, deterministic naming,
   metadata resolution, safe junction removal, and fallback cleanup behavior.

## Validation

1. Parse both PowerShell scripts with the PowerShell AST parser.
2. Run the CRP-199 focused Pester suite.
3. Run `git diff --check` on the CRP-199 scope.
4. Dispatch a BCompare review for `LCM_Inventory` against `HEAD` using
   `CRP-199` after automated validation passes.