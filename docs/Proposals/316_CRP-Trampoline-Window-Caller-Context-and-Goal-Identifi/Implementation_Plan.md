# Implementation Plan: CRP-316 - Trampoline Window Caller Context and Goal Identification Header

## 1. Executive Summary & Problem Context
When an LCM command trampoline (`Cmd/*.cmd`) launches a PowerShell session, display a clear identification header banner in the console window identifying the caller and goal of the shell invocation.

## 2. Gate 0 Traceability
- **Caller & Goal Display**: Injects header output before launching the tool target.
- **Generator Parity**: Extends `Update-ToolCatalog.ps1` to emit this header across all managed trampolines.
- **Non-Interference**: Forwarding of `%*` and return of `%ERRORLEVEL%` preserved without degradation.

## 3. Proposed Changes
### Component 1: Trampoline Generator Extension (`LCM_Inventory/tools/Update-ToolCatalog.ps1`)
- Update trampoline template for PowerShell tools to output:
  ```cmd
  echo ======================================================================
  echo  [LCM Launcher] Caller: %~nx0 ^| Goal: <Tool Goal>
  echo ======================================================================
  ```
  prior to delegating execution to `pwsh.exe`.

### Component 2: Regenerate Cmd Trampolines
- Run `Update-ToolCatalog.ps1` to update the catalog-managed trampolines in `LCM_Inventory/Cmd/`.

## 4. Verification Plan
- Invoke sample trampolines (e.g. `ShowTools.cmd -h`) and confirm banner appearance and argument fidelity.
- Pester test to ensure return codes and argument forwarding remain 100% compliant.
