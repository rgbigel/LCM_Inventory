# Execution Walkthrough: CRP-221

```yaml
CRP-ID: CRP-221
Title: Distinguish Cancelled vs Rejected & Preserve Baseline Scratchpad Timestamps
Scope: LCM_AI, LCM_Inventory
Author: rgbig
Date: 2026-10-03 19:15:58
```

---

## 1. Summary of Changes Executed

1. **Codified RULE-LCM-002 Commands in `ProposalReviewFlowPolicy.md`**:
   - `cancel <all, #n, #n-#m>`: Explicitly documented as Gate 1 administrative ticket withdrawal (intake/scoping/ratification drop) with zero working-tree modifications and zero code reverts. Flow switches unconditionally turned OFF.
   - `reject <all, #n, #n-#m>`: Explicitly documented as Gate 2 review rejection (visual inspection/verification failure) triggering active rollback of working-tree modifications back to the clean pre-CRP baseline. Flow switches unconditionally turned OFF.

2. **Codified RULE-LCM-007 Dispositions & Matrix**:
   - Defined `Cancelled` as administrative Gate 1 ticket withdrawal.
   - Defined `Rejected` as physical implementation Gate 2 rejection with active rollback.
   - Split Matrix table rows into `[Terminal] Cancelled` (Gate 1, zero reverts) and `[Terminal] Rejected` (Gate 2, rollback to baseline).
   - Updated Mermaid state diagram with separate `cancel` paths (Suggested, Scoped, Decided -> Cancelled) and `reject` paths (Verified, In_Progress -> Rejected).

3. **Preserved Baseline Scratchpad Timestamps**:
   - Updated `Export-BCompareBaseline` in [`BCompareBaseline.psm1`](file:///d:/Git_Repositories/LCM_Inventory/modules/BCompareBaseline.psm1): after extracting baseline tar archives, every file's `CreationTime` and `LastWriteTime` are set via .NET. Unchanged files match the working copy timestamps; modified or rule files reflect their Git commit timestamps.
   - Updated `New-CompactBCompareReviewTree` in [`CompactBCompareReview.psm1`](file:///d:/Git_Repositories/LCM_Inventory/modules/CompactBCompareReview.psm1): working targets preserve source file creation and write timestamps; baseline targets receive matching working timestamps if identical or Git commit dates.
   - Verified that files materialized into `scratch/BC_Review/` maintain their historical timestamps rather than "now".

4. **Enforced Idempotent Single-Window Tab Activation**:
   - Updated [`Invoke-BeyondCompareReview.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1): inspects running `BCompare.exe` processes via WMI. If a session for the target CRP or repository is already active, `Start-Process` is suppressed and the existing window is activated directly via `AppActivate`, preventing duplicate tab creation.

5. **Test Results**:
   - `tests/BCompareBaseline.Tests.ps1`: 4/4 passed (including `preserves historical file timestamps on exported baseline files`).
   - `tests/CompactBCompareReview.Tests.ps1`: 3/3 passed.
   - `tests/BCompareWindowTools.Tests.ps1`: 3/3 passed.
