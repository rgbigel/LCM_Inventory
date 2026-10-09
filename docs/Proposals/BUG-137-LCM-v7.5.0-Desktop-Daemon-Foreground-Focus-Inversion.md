# Bug Report: BUG-137
# Desktop Daemon Foreground Focus Inversion on Target Launch

| Metadata Field | Value |
| :--- | :--- |
| **Bug ID** | `BUG-137` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Activation per RULE-LCM-015) |
| **Origin Repository** | `LCM / Git_Repositories` |
| **Target Scope** | `LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1` |
| **Author** | Operator Directive / BUG Intake |
| **Date** | 2026-09-11 |
| **Severity** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-008`, `RULE-LCM-010`, `RULE-LCM-015`) |
| **Originating Proposal** | [`BUG-133`](file:///D:/Git_Repositories/LCM_Inventory/docs/Proposals/BUG-133-LCM-v7.5.0-Tool-Explorer-UI-Regressions-Help-And-Parameter-Fixes.md) (Desktop Daemon /open Target Activation) |

---

## 1. Defect Summary & Symptoms

When launching tools or files with `Foreground: True` (such as opening logs in Notepad via `ShowActions` or `/open` endpoint):
1. The launched editor window appears in the background behind the browser dashboard.
2. The user perceives the action as a no-op until discovering the window minimized or layered underneath other windows.

---

## 2. Root Cause Analysis

1. In `DaemonActionController.ps1` (`OpenTarget`, lines 58–67):
   ```powershell
   if ($req.Foreground) {
     Start-Sleep -Milliseconds 400
     $wsh = New-Object -ComObject WScript.Shell
     if ($req.Title) {
       $null = $wsh.AppActivate($req.Title)
     } else {
       $null = $wsh.AppActivate("LCM Tool Explorer")
       $null = $wsh.AppActivate("SHOW_TOOLS")
     }
   }
   ```
2. When launching an external editor or viewer without an explicit `$req.Title`, the fallback branch actively executes `$wsh.AppActivate("LCM Tool Explorer")`.
3. This inverts the focus: it pulls the browser window *forward*, deliberately burying the newly launched application behind the dashboard.

---

## 3. Proposed Remediation Plan

1. In `DaemonActionController.ps1`, capture the `[System.Diagnostics.Process]` handle returned by `[System.Diagnostics.Process]::Start($psi)`.
2. When `$req.Foreground` is true and `$req.Title` is not provided:
   - Wait briefly for the target process's `MainWindowHandle`.
   - Bring the target process window to the foreground rather than falling back to "LCM Tool Explorer".
   - Only activate "LCM Tool Explorer" when the target itself is an HTML dashboard or when explicitly requested.
