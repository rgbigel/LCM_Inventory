# Implementation Plan - CRP-320: Unified Tool Gateway & Simplified Execution Architecture (LCM DO)

Module: docs/Proposals/CRP-320-CRP-320-Unified-Tool-Gateway-and-Simplified-Execut/Implementation_Plan.md  
Purpose: Step-by-step engineering plan for retiring redundant dispatchers, standardizing direct trampolines, and establishing LCM DO as the unified execution gateway.  
Path: docs/Proposals/CRP-320-CRP-320-Unified-Tool-Gateway-and-Simplified-Execut/Implementation_Plan.md  
Authors: Rolf, Antigravity  
Version: 1.0.0  
Date: 2026-11-11  

---

## User Review Required

> [!IMPORTANT]
> **Retirement of `Invoke-PrivilegedTool.ps1`**: All trampolines will transition from calling `Invoke-PrivilegedTool.ps1` to calling `do.cmd` / `Invoke-LcmDo.ps1` when elevation is required, or calling native binaries directly without PowerShell wrappers.

---

## Proposed Changes

### 1. `LCM_Inventory/tools/Invoke-LcmDo.ps1` & `do.cmd`
- Finalize `Invoke-LcmDo.ps1` with structured logging, execution statistics collection, and telemetry logging to `data/telemetry/tool_usage.json`.
- Add `-Stats` parameter to display real-time execution counts, average duration, and error frequencies.

### 2. `LCM_Inventory/tools/Update-ToolCatalog.ps1`
- Refactor trampoline code generation:
  - When `Type -eq 'Executable'`: Generate direct execution trampolines (`"%targetRef%" %*`) without wrapping in `pwsh.exe`.
  - When `Admin -eq $true`: Replace the `Invoke-PrivilegedTool.ps1` trampoline block with:
    ```cmd
    net session >nul 2>&1
    if %errorlevel% neq 0 (
      call "%Git_Root%\LCM_Inventory\Cmd\do.cmd" -Command "%~nx0 %*" -Elevated -NoExit
      exit /b
    )
    ```
- Eliminate legacy references to `Invoke-PrivilegedTool.ps1`.

### 3. Retire Redundant Dispatchers
- Deprecate and archive `LCM_Inventory/tools/Invoke-PrivilegedTool.ps1`.
- Clean up outdated trampoline artifacts and regenerate all 231 command trampolines cleanly.

### 4. Search & IPC Hardening (`Search-Everything.ps1`)
- Ensure `Search-Everything.ps1` strictly routes through `Invoke-LcmDo` when running in a sandbox.
- Permanently purge any residual recursive disk crawl fallbacks.

---

## Verification Plan

### Automated Tests:
- Run `Test-RepoReadiness.ps1 -MinimalTests` across `LCM_Inventory`.
- Execute unit test verifying direct execution of `.exe` trampolines without PowerShell process spawn.
- Verify telemetry record creation in `data/telemetry/tool_usage.json`.

### Manual / Visual Verification:
- Launch `do.cmd -Command "es.exe FolderTimeUpdate -n 3" -Sync` and confirm sub-second output.
- Launch `FolderTimeUpdate.cmd` and confirm direct GUI display with zero hanging windows.
