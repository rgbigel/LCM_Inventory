# Implementation Plan: BUG-245 - BCR Foreground Console Window Hygiene and Premature Review Scratchpad Purge

## 1. Executive Summary & Defect Remediation Scope
Fixes the two Beyond Compare Review defects: (1) eliminates the spurious foreground PowerShell console window on launch by passing `windowStyle = "Hidden"` and optimizing direct `.exe` execution in the daemon; (2) prevents Beyond Compare path-not-found fast refresh errors by deferring scratchpad directory deletion whenever `BCompare.exe` is actively running.

---

## 2. Proposed Changes

### Phase 1: Window Style & Direct Dispatch Optimization
- In [`LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1):
  - Change line 885 from `windowStyle = "Normal"` to `windowStyle = "Hidden"`.
  - Also ensure other multi-repo tab launches via `/execute` (line 950) pass `windowStyle = "Hidden"`.
- In [`DaemonActionController.ps1`](file:///D:/Git_Repositories/LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1):
  - Detect if `cmdToRun` is a direct `.exe` GUI application and launch directly with `Start-Process` without wrapping in `pwsh.exe`.

### Phase 2: Scratchpad Deletion Safety & Beyond Compare Process Awareness
- In [`LCM_Inventory/tools/Submit-ReviewResult.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Submit-ReviewResult.ps1):
  - In lines 375–393, inspect if `BCompare.exe` process is currently active:
    ```powershell
    $bcRunning = [bool](Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'" -ErrorAction SilentlyContinue)
    ```
  - If `$bcRunning`, log that scratchpad purge is deferred to avoid interrupting active review windows, and leave the baseline/live scratch folders intact.
  - If NOT running, proceed with safe scratchpad deletion.

---

## 3. Verification & Quality Gates
- Test AST syntax on `Invoke-BeyondCompareReview.ps1`, `Submit-ReviewResult.ps1`, and `DaemonActionController.ps1`.
- Verify Beyond Compare launches with zero console windows.
- Verify `Submit-ReviewResult.ps1` runs without triggering Beyond Compare refresh path errors.
