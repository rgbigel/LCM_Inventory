# Implementation Plan: CRP-196

1. Define canonical states, transition metadata, fast-complete receipts,
   post-commit review receipts, and legacy-state migration rules.
2. Refactor lifecycle services so `Commit` stages and creates the local commit,
   then transitions to `Review Commit` rather than directly to `Completed`.
3. Build status filters and valid-action menus from transition metadata.
4. Replace the sidecar with a contextual `Actions` dropdown and a global App
   focus control.
5. Implement `Review Commit` as an automatic BCompare launch from the parent
   commit to the live local commit, with both compared SHAs recorded in the
   review receipt.
6. Detect any right-pane/live-working-tree modification during the review;
   invalidate the receipt, return the CRP to `in_progress`, and force
   verification before the next local commit.
7. Implement the lifecycle rail, reverse routes, held route, and review tools.
8. Add migration, transition, UI workflow, right-side-mutation, forced-test,
   and no-push-before-clean-review tests.