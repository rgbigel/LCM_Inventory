# Change Request Proposal: CRP-221

```yaml
CRP-ID: CRP-221
Title: Distinguish Cancelled vs Rejected & Preserve Baseline Scratchpad Timestamps
Scope: LCM_AI, LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13 19:15:58
Status: Verified
Plan-State: approved
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent

1. **Cancelled vs. Rejected Distinction in Governance**:
   Codify the formal distinction between `Cancel` / `Cancelled` and `Reject` / `Rejected` across the Lifecycle Model governance framework in [`ProposalReviewFlowPolicy.md`](file:///d:/Git_Repositories/LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md):
   - **`Cancel` / `Cancelled`**: Ticket withdrawal (administrative). Indicates the CRP is dropped or superseded at Gate 1 (during intake, scoping, or planning ratification). Involves **zero working-tree modifications**, zero code reverts, and zero rule modifications.
   - **`Reject` / `Rejected`**: Implementation rejection at Gate 2. Indicates physical implementation rejection during visual diff review (`Verified` review checkpoint). Actively rolls back and undoes working-tree modifications introduced by the CRP, returning the repository to its clean pre-CRP baseline (or full cohort rollback for batches).

2. **Preserve Original Timestamps on Baseline Scratchpad for Beyond Compare Reviews**:
   When baseline files are extracted or copied into the review scratchpad (`Export-BCompareBaseline` in `BCompareBaseline.psm1` and `New-CompactBCompareReviewTree` in `CompactBCompareReview.psm1`), preserve original historical timestamps:
   - For files derived from or identical to working tree files, preserve `CreationTime` and `LastWriteTime` from the working copy.
   - For modified baseline files, resolve timestamps from the Git commit date (`git log -1 --format=%cI`).
   - Set timestamps explicitly via .NET `[System.IO.File]::SetLastWriteTime` and `[System.IO.File]::SetCreationTime` so timestamps are not corrupted to "now".

3. **Idempotent Single-Window Review Tab Enforcement**:
   Ensure `Invoke-BeyondCompareReview.ps1` checks for already-open review sessions before dispatching to Beyond Compare, preventing duplicate tabs for the same comparison.
