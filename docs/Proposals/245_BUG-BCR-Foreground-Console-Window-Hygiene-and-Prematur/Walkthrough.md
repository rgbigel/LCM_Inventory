# Walkthrough: BUG-245 - BCR Foreground Console Window Hygiene and Premature Review Scratchpad Purge

## 1. Overview
Validates that:
1. Beyond Compare 5 review launch via daemon produces zero lingering or flashing PowerShell console windows on the operator desktop.
2. `Submit-ReviewResult.ps1` respects running `BCompare.exe` processes and avoids deleting active scratchpad paths during review.

---

## 2. Test Scenarios

### Scenario 1: Clean BCR Launch without Console Window
- **Action:** Run `Invoke-BeyondCompareReview.ps1 -RepositoryName LCM_Inventory -CRP BUG-245`.
- **Expected:** Beyond Compare opens cleanly on interactive desktop Session 1. No PowerShell console window pops up or lingers.

### Scenario 2: Active Beyond Compare Session Scratchpad Protection
- **Condition:** Beyond Compare is open with review files loaded.
- **Action:** Run `Submit-ReviewResult.ps1 -RepositoryPath LCM_Inventory -Result CompleteAll -All`.
- **Expected:**
  - Changes commit cleanly.
  - Review manifest is purged.
  - Active scratchpad is preserved because `BCompare.exe` is running.
  - Beyond Compare does NOT throw "Unable to load... path specified" fast refresh errors.
