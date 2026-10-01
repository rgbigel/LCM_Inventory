# Implementation Plan: CRP-186

## Scope Breakdown
1. **Authoritative Ledger Update**:
   - File: `LCM_Inventory/data/proposals/proposals.json`
   - Update proposal 184: `state = "in_progress"`, `progress_state = "in_progress"`.
   - Add new record for `CRP-186` with `state = "in_progress"`.
2. **Review Tag Condensation**:
   - File: `LCM_Inventory/assets/CM_CONTROL_HUB.html`
   - Implement `formatBatchReviewTag(proposals, defaultRepo)` function.
   - Refactor `executeBatchReview()` to use `formatBatchReviewTag`.
3. **Verification**:
   - Test unit cases for `formatBatchReviewTag`:
     - Range `[183, 184, 185]` $\rightarrow$ `CRP-183-185`.
     - Range `[183, 184]` $\rightarrow$ `CRP-183-184`.
     - Non-contiguous `[182, 185]` $\rightarrow$ `CRP-182+185`.
     - Single item `[183]` $\rightarrow$ `BUG-183` (original bundle_id preserved).
   - Verify `proposals.json` validity and proposal 184 state transition.
