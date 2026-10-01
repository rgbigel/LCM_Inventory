# Implementation Plan: CRP-203

1. Inspect the dynamic BCompare session naming and review-cache ownership
   established by `Invoke-BeyondCompareReview.ps1`.
2. Add a dedicated cleanup tool with explicit repository and CRP/BUG inputs,
   preview mode, structured result, and scoped audit logging.
3. Remove only the matching BCompare saved-session entry and the matching
   `scratch\BC_Review\<CRP-or-BUG>` cache tree after verifying ownership.
4. Integrate the cleanup call after `Submit-ReviewResult.ps1` records a
   successful local commit; preserve commit success if cleanup reports failure.
5. Add focused Pester coverage for exact-match selection, unrelated-session
   preservation, preview behavior, post-commit invocation, and failure logging.
6. Parse the touched scripts, run focused tests, and perform a BCompare review
   before any commit.