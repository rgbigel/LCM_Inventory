# Walkthrough: CRP-196

## Gate 1 Record

The Control Hub redesign is registered as a standalone proposal. No source or
UI implementation has been started. It awaits explicit lifecycle activation.

## Suggested Design Amendment

The proposal now includes a post-local-commit `Review Commit` step. The
automatic BCompare review will compare the local parent commit to the live
working tree at the new local commit. A right-side modification invalidates the
receipt, returns the CRP to `in_progress`, and forces verification before a new
commit/review cycle. This is a Gate 1 design update only; no runtime behavior,
lifecycle state, or implementation file has changed.