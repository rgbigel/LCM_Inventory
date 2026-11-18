# Defect Specification: BUG-245

```yaml
BUG-ID: BUG-245
Title: BCR Foreground Console Window Hygiene and Premature Review Scratchpad Purge
Scope: LCM_Inventory, Root (LCM_Inventory/modules/LcmDaemon)
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Defect Description

During interactive Beyond Compare Review (BCR) workflows, two disruptive runtime behaviors occur:

1. **Foreground PowerShell Window Popup**:
   - Immediately before Beyond Compare appears, a visible PowerShell console window pops up in the foreground. It lingers on the interactive desktop and is never closed automatically.
2. **Premature Scratchpad Purge Causing Beyond Compare Refresh Errors**:
   - When `Submit-ReviewResult.ps1` commits a review, it immediately deletes the entire scratch directory (`LCM_Inventory\scratch\BC_Review\CRP-nnn`).
   - Beyond Compare 5 (which is still open in the background with file watchers active) detects the sudden deletion of its loaded paths during auto-refresh, throwing an error dialog:
     ```
     2026-10-13 16:19:10 Fast refresh
     2026-10-13 16:19:10 Unable to load ...\scratch\BC_Review\CRP-243\Baseline_...: The system cannot find the path specified
     2026-10-13 16:19:10 Unable to load ...\scratch\BC_Review\CRP-243\Live_...: The system cannot find the path specified
     ```
   - In multi-repository CRP cohorts, this prematurely destroys the baseline folders for subsequent repos before they can be reviewed.

---

## 2. Root Cause Analysis

### Defect 1: Foreground Console Window
- In [`LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1) (lines 883–887):
  ```powershell
  $execPayload = @{
    command = "& `"$BeyondComparePath`" $sessionName"
    windowStyle = "Normal"
  } | ConvertTo-Json
  $null = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/execute" -Method Post -Body $execPayload ...
  ```
- In [`DaemonActionController.ps1`](file:///D:/Git_Repositories/LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1) (lines 262–265):
  ```powershell
  Start-Process -FilePath "pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass $noExitFlag-EncodedCommand $encodedCmd" -WindowStyle $windowStyle
  ```
- Because `windowStyle` was set to `"Normal"`, the daemon starts an interactive `pwsh.exe` console window in the foreground solely to execute `BCompare.exe`.

### Defect 2: Premature Scratchpad Deletion
- In [`LCM_Inventory/tools/Submit-ReviewResult.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Submit-ReviewResult.ps1) (lines 375–393):
  ```powershell
  # Purge the entire CRP review directory (BC_Review\CRP-nnn\) post-commit.
  Remove-Item -LiteralPath $crpReviewDirToPurge -Recurse -Force -ErrorAction SilentlyContinue
  ```
- Deleting the active directory while `BCompare.exe` has file watchers bound to it instantly triggers Beyond Compare's "Fast refresh" path failure error.

---

## 3. Required Remediation

### Remediation 1: Console Window Elimination
1. In `Invoke-BeyondCompareReview.ps1`:
   - Set `windowStyle = "Hidden"` when calling `/execute`.
2. In `DaemonActionController.ps1`:
   - When the dispatched command is a direct Windows GUI executable (`.exe`), launch the executable directly via `Start-Process -FilePath $exePath -ArgumentList $remArgs -WindowStyle $windowStyle` rather than wrapping it in an unnecessary `pwsh.exe` console process.

### Remediation 2: Safe Scratchpad Lifecycle & Purge Deferral
1. In `Submit-ReviewResult.ps1`:
   - Do NOT delete the entire `scratch\BC_Review\CRP-nnn\` directory while `BCompare.exe` is actively running.
   - Check if `BCompare.exe` is running (`Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'"`). If running, preserve the directory so Beyond Compare does not crash or throw path errors.
   - Defer full scratchpad cleanup to session exit, `Clear-BCReviewTemp.ps1`, or when the next review session initializes.
   - Only purge the single repository's `pending_commit_${repoName}.json` and `staged_review_${repoName}.json` authorization files.

---

## 4. Verification Criteria
- [ ] Dispatching BCR via daemon opens Beyond Compare directly on Session 1 without any visible PowerShell console window flashing or lingering.
- [ ] Running `Submit-ReviewResult.ps1` while Beyond Compare is open completes cleanly without triggering Beyond Compare "Unable to load... path specified" fast refresh errors.
- [ ] Multi-repository review workflows maintain scratchpad integrity across all cohort repositories.
