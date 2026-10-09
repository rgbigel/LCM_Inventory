# BUG-124: BCR Junction Exclusion Filter Defect and Directory Root Boundary Isolation

```yaml
id: BUG-124
title: BCR Junction Exclusion Filter Defect and Directory Root Boundary Isolation
scope: LCM_Inventory / BCR
status: deferred
progress_state: deferred
priority: Low
authors: rgbig, LCM_AI Engine
created_at: 2026-09-08T19:25:00+02:00
target_scope: LCM_Inventory
affected_version_range: v1.1.2
impacted_repositories:
  - LCM_Inventory
```

---

## 1. Issue Summary

During Beyond Compare visual review (`Invoke-BeyondCompareReview.ps1`), when a repository contains NTFS junctions (such as `.agents` or `.agents\rules`), the primary comparison session only excludes `-.agents\rules\` rather than `-.agents\`. 

Consequently:
1. The `.agents` directory is still visible in the primary comparison tree.
2. In the secondary comparison window, the junction destination (e.g. `.agents\rules`) is opened, resulting in overlapping visual display where parts of `.agents` show in both the primary and secondary windows.
3. The primary comparison window should completely exclude `-.agents\` (and any detected junction root), ensuring the secondary session exclusively owns the review of `.agents` using `.agents\rules` (or `.agents`) as its clean directory root.

---

## 2. Root Cause Analysis

In [`LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`](file:///d:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1#L585):
```powershell
# Exclude child repo junction directories
$junctionFilters = @('-.agents\rules\', '-*\.agents\rules\*', '-.agents\rules\', '-*\.agents\rules\*', '-.copilot\skills\', '-*\.copilot\skills\*')
```
1. It explicitly filters `-.agents\rules\`, but leaves the parent `.agents` container unmasked in child repositories.
2. When `.agents` is an NTFS junction, or when `.agents` contains junction child folders, `.agents` continues to display in the primary comparison view.
3. The exclusion list in the primary comparison must include `-.agents\` and `-*\.agents\*` whenever `.agents` or any of its subdirectories is a junction.

---

## 3. Remediation Plan

1. Update `Invoke-BeyondCompareReview.ps1` (`v2.3.2`):
   - In the exclusion filter generation (Section 5), add `-.agents\` and `-*\.agents\*` to `$junctionFilters`.
   - Dynamically inspect all detected junctions: if any junction is within `.agents` or is `.agents`, guarantee both `-.agents\` and `-*\.agents\*` are in `$filterList`.
   - Ensure the secondary session exclusively compares the junction root (`.agents\rules` or `.agents`) without any residual appearance in the primary window.
2. Verify with test executions against child repositories (`Installation_LCD`).
