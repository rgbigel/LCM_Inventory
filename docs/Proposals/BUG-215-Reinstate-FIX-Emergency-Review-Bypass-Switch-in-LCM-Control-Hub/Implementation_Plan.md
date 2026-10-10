# BUG-215 Implementation Plan

1. Inspect current Control Hub actions, their API dispatch, and the review-result command path.
2. Determine whether the FIX action was removed, hidden, disconnected, or blocked by a policy check.
3. Restore only the missing operator-authorized action and preserve normal review-gate behavior.
4. Add focused tests for visible action availability, authorized dispatch, and audit receipt.

