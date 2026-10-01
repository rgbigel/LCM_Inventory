---
Proposal-ID: BUG-112
CR-ID: BUG-112
Scope: LCM / Command Launchers & Dispatch
Version: v7.3.0
Affected-Repos: [LCM, LCM_Inventory]
Status: OPEN
Date: 2026-09-07
Author: rgbig
Target Scope: .lcm/Cmd/ShowCrpDates.cmd, .lcm/Cmd/*.cmd, .lcm/tools/internal/Invoke-InteractiveDesktop.ps1
Affected Version Range: v7.3.0
Impacted Repositories: [LCM, LCM_Inventory]
Severity: High
---

# BUG-112 / BUG-112: Unresolved %Git_Root% Variable in CMD Launchers and Dispatchers

## 1. Defect Description & Discovery Vector
When invoking command launchers such as `ShowCrpDates.cmd` or running dispatch scripts when the environment variable `%Git_Root%` is unset or empty in the active shell environment, the target script path evaluates to:
```
/LCM_Inventory/tools/Show-CrpDates.ps1
```
PowerShell rejects this path with a fatal error:
```
The argument '/LCM_Inventory/tools/Show-CrpDates.ps1' is not recognized as the name of a script file. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

## 2. Root Cause Analysis
1. **Unchecked %Git_Root% Environment Variable in Batch Launchers**:
   In `.lcm/Cmd/ShowCrpDates.cmd` (and potentially other `.cmd` launchers in `.lcm/Cmd/`), the command executes:
   ```cmd
   pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Show-CrpDates.ps1" %*
   ```
   If `%Git_Root%` is not defined in the process environment (e.g. standard PowerShell prompt or Windows Command Prompt without primed profile variables), `%Git_Root%` evaluates to an empty string. The argument collapses to `"/LCM_Inventory/tools/Show-CrpDates.ps1"`, which points to the drive root rather than the workspace container root `D:\Git_Repositories\`.
2. **Missing Dynamic Drive / Workspace Anchor Resolution**:
   CMD wrappers should determine their own directory root relative to `%~dp0` (e.g. `%~dp0..\..`) or fallback to `D:\Git_Repositories` if `%Git_Root%` is not set.

## 3. Remediation Strategy (Proposed)
1. **Robust Anchor Fallback in CMD Launchers**:
   Update `.lcm/Cmd/ShowCrpDates.cmd` and audit all `.cmd` launchers under `.lcm/Cmd/` to ensure robust root resolution:
   ```cmd
   @echo off
   setlocal
   if not defined Git_Root set "Git_Root=%~dp0..\.."
   if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
   pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%\LCM_Inventory\tools\Show-CrpDates.ps1" %*
   ```
2. **Audit and Synchronize All CMD Launchers**:
   Ensure all `.cmd` files in `.lcm/Cmd/` declare this self-healing path resolution logic.
3. **Verification**:
   Execute `ShowCrpDates.cmd` in a clean environment where `Git_Root` is unset to confirm successful resolution.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this bug proposal is registered in the `OPEN` state. Detailed implementation planning and code edits will begin upon receipt of an explicit `PROCEED 112` or `PROCEED ALL` command.

