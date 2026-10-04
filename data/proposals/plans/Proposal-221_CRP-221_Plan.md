# Implementation Plan: CRP-221

```yaml
CRP-ID: CRP-221
Title: Distinguish Cancelled vs Rejected & Preserve Baseline Scratchpad Timestamps
Scope: LCM_AI, LCM_Inventory
Author: rgbig
Date: 2026-10-03 19:15:58
```

---

## 1. Implementation Steps

1. **Update RULE-LCM-002 (Batch Execution & Control Commands)**:
   - Split `cancel` and `reject` into distinct commands.
   - Define `cancel <all, #n, #n-#m>` as Gate 1 administrative withdrawal with zero code reverts.
   - Define `reject <all, #n, #n-#m>` as Gate 2 review rejection with active working-tree rollback to pre-CRP baseline.

2. **Update RULE-LCM-007 (Flat Lifecycle Continuum & Dispositions)**:
   - Distinguish `Cancelled` and `Rejected` dispositions in Section 3.
   - Update Canonical Flat Lifecycle Matrix: split `[Condition] Cancelled` row into `[Terminal] Cancelled` (Gate 1, zero reverts) and `[Terminal] Rejected` (Gate 2, rollback to baseline).
   - Update Canonical Mermaid State Diagram: render separate branches for `cancel` (from Suggested, Scoped, Decided) and `reject` (from Verified / In_Progress).

3. **Preserve Timestamps in Baseline Modules**:
   - In `LCM_Inventory/modules/BCompareBaseline.psm1` (`Export-BCompareBaseline`): post-extraction, set file `CreationTime` and `LastWriteTime` from matching working files (if identical) or the target/rules Git commit timestamp using .NET `[System.IO.File]::SetCreationTime` and `SetLastWriteTime`.
   - In `LCM_Inventory/modules/CompactBCompareReview.psm1` (`New-CompactBCompareReviewTree`): preserve source working copy timestamps on working targets, and match working timestamps or commit dates on baseline targets.

4. **Prevent Duplicate Tabs in Beyond Compare Review Launch**:
   - In `LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`: query existing BCompare processes via WMI. If a process is already running with the target session name or CRP, bring the existing window to the front without calling `Start-Process` again.

5. **Verification & Tests**:
   - Add unit test to `tests/BCompareBaseline.Tests.ps1` verifying historical timestamp preservation.
   - Execute test suites (`BCompareBaseline.Tests.ps1`, `CompactBCompareReview.Tests.ps1`, `BCompareWindowTools.Tests.ps1`).
