# Implementation Plan: BUG-200

1. Wrap the normalized directive-line pipeline in `@(...)` in
   `Audit-BeyondCompareReviewStaging`.
2. Add a focused Pester contract that requires array normalization before the
   subsequent `Count` checks.
3. Re-run the focused BCompare lifecycle tests.
4. Re-dispatch the CRP-199 BCompare review and verify that the audit completes.