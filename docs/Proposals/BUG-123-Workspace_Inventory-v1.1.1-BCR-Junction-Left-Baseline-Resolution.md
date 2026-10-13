# BUG-123: Beyond Compare Review Junction Left Pane Baseline Resolution Defect

```yaml
id: BUG-123
title: Beyond Compare Review Junction Left Pane Baseline Resolution Defect
scope: LCM_Inventory / BCR
status: in_progress
progress_state: in_progress
priority: High
authors: rgbig, LCM_AI Engine
created_at: 2026-09-08T16:22:00+02:00
target_scope: LCM_Inventory
affected_version_range: 10.0.0
impacted_repositories:
  - LCM_Inventory
```

---

## 1. Issue Summary

When `Invoke-BeyondCompareReview.ps1` (`BCR`) executes against any repository containing an NTFS directory junction (such as `.agents` or `.agents\rules`), it opens a secondary Beyond Compare session per [`RULE-REV-008`](file:///d:/Git_Repositories/.agents/rules/ReviewCommitGovernancePolicy.md). 

While the right pane correctly loads the live junction target (`D:\Git_Repositories\LCM_Inventory\.agents`), the left pane attempts to load `$tempReviewRoot\$rel` (`<tempReviewRoot>\.agents`). In the Root Container (`Git_Repositories`), Git physically tracks governance files under `LCM_Inventory/.agents/*` while ignoring the root `.agents` junction. Consequently, the left baseline folder is empty or unlinked, preventing visual comparison of rule and governance modifications against the committed Git baseline.

---

## 2. Root Cause Analysis

In [`LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1#L728):
```powershell
$leftJunctionPath = Join-Path $tempReviewRoot $rel
if (-not (Test-Path -LiteralPath $leftJunctionPath)) {
  New-Item -ItemType Directory -Path $leftJunctionPath -Force | Out-Null
}
```
1. When `$RepoName` is `Git_Repositories`, the relative junction path is `$rel = ".agents"`.
2. The Git tree of `Git_Repositories` does not contain `.agents` (it is in `.gitignore`). Instead, the committed files reside in `LCM_Inventory\.agents`.
3. Creating an empty folder at `$tempReviewRoot\.agents` results in an empty left comparison pane in Beyond Compare.
4. Furthermore, for child repositories, if the baseline doesn't track `.agents`, the left pane should point to the committed baseline of the junction target in the source repository (`Git_Repositories` at `HEAD`).

---

## 3. Remediation Plan

1. Modify `Invoke-BeyondCompareReview.ps1`:
   - Inspect `$targetPath` and `$rel`.
   - If `$RepoPath -eq $workspaceRoot` and `$rel -eq '.agents'`:
     - Map `$leftJunctionPath` to `Join-Path $tempReviewRoot 'LCM_Inventory\.agents'`.
   - If `$RepoPath -ne $workspaceRoot` and `$rel -eq '.agents'`:
     - If the child repo does not have files in its baseline snapshot at `$tempReviewRoot\.agents`, resolve the baseline from `Git_Repositories` committed `LCM_Inventory/.agents` so the comparison is meaningful.
   - If the mapped `$leftJunctionPath` exists and has files, use it; otherwise provide a descriptive warning and ensure the session opens against the true backing baseline.
2. Verify that launching `Invoke-BeyondCompareReview.ps1 Git_Repositories` opens the second session with the left pane pointing to the populated baseline (`Git_Repositories_xxx\LCM_Inventory\.agents`).
