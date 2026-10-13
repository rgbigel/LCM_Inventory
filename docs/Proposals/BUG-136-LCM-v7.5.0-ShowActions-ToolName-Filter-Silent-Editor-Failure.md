# Bug Report: BUG-136
# Show-Actions ToolName Log Filter and Silent Editor Failure

| Metadata Field | Value |
| :--- | :--- |
| **Bug ID** | `BUG-136` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Activation per RULE-LCM-015) |
| **Origin Repository** | `LCM / Git_Repositories` |
| **Target Scope** | `LCM_Inventory/tools/Show-Actions.ps1` |
| **Author** | Operator Directive / BUG Intake |
| **Date** | 2026-10-13 |
| **Severity** | `Medium` |
| **Version Impact** | `10.0.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-008`, `RULE-LCM-010`, `RULE-LCM-015`) |
| **Originating Proposal** | [`BUG-133`](file:///D:/Git_Repositories/LCM_Inventory/docs/Proposals/BUG-133-LCM-10.0.0-Tool-Explorer-UI-Regressions-Help-And-Parameter-Fixes.md) (Tool Explorer Execution & Parameter Integration) |

---

## 1. Defect Summary & Symptoms

When running `Show-Actions` with parameter `-ToolName ShowActions` (or `Show-Actions`) and `-Open`:
1. The command terminates without opening the editor (Notepad).
2. Diagnostic output shows `Dispatching execution: ShowActions -Count "15" -Detailed -ToolName "ShowActions" -Open` but no editor window is launched.
3. Running with `NoExit` shows recent daemon actions but no result for `ShowActions` itself.

---

## 2. Root Cause Analysis

1. In `Show-Actions.ps1` (lines 92–103):
   ```powershell
   $logFiles = @(Get-ChildItem -Path $logDir -Filter "*.log" -File | 
     Where-Object { 
       $_.Name -notlike "Invoke-InteractiveDesktop-*" -and
       ([string]::IsNullOrWhiteSpace($ToolName) -or $_.Name -like "*$ToolName*")
     } | 
     Sort-Object LastWriteTime -Descending | 
     Select-Object -First $Count)

   if ($logFiles.Count -eq 0) {
     Write-Host "No matching action logs found in $logDir." -ForegroundColor Yellow
     return
   }
   ```
2. `Show-Actions.ps1` is a reader utility and does not emit log files named `ShowActions-*.log`.
3. When the Tool Explorer or operator provides `-ToolName "ShowActions"`, the filter `$_.Name -like "*ShowActions*"` matches zero files.
4. The script exits early at line 102 before reaching line 105 (`if ($Open)`).
5. In non-interactive or background console execution, this results in an apparent silent failure with no editor launched.

---

## 3. Proposed Remediation Plan

1. In `Show-Actions.ps1`, when `$ToolName` matches `Show-Actions` / `ShowActions`, recognize that it targets the overall action log repository (e.g. `LcmDesktopDaemon-*.log` or most recent action logs) rather than filtering exclusively for nonexistent self-logs.
2. If zero log files match `$ToolName`, provide an informative warning and, if `-Open` was requested, fallback to opening the most recent general action log (`LcmDesktopDaemon-*.log`).
3. Handle aliases and short names flexibly (e.g. strip hyphens and check against tool name variations).
