# Implementation Plan: CRP-317 - Eliminate Git_Root Escape Fallback Logic for Multi-Workspace and Sandbox Isolation

## 1. Executive Summary & Problem Context
Eliminate hardcoded fallback/escape logic (such as `if not exist ... set "Git_Root=D:\Git_Repositories"`) across command trampolines and scripts. This ensures strict isolation across workspaces and establishes a clean foundation for upcoming HKLM "Sandbox n" redirection.

## 2. Gate 0 Traceability
- **Elimination of Escape Fallback**: `$gitRootPreamble` in `Update-ToolCatalog.ps1` no longer defaults to `D:\Git_Repositories`.
- **Fail-Closed Verification**: Trampolines abort with code 1 if their parent workspace structure is invalid or missing.
- **Multi-Workspace & Sandbox Readiness**: Dynamic resolution based purely on relative location `%~dp0..\..` (or explicit environment / HKLM designation).

## 3. Proposed Changes
### Component 1: Update Trampoline Generator (`LCM_Inventory/tools/Update-ToolCatalog.ps1`)
- Refactor `$gitRootPreamble` to remove `set "Git_Root=D:\Git_Repositories"`.
- Replace with fail-closed structure check:
  ```cmd
  if not defined Git_Root set "Git_Root=%~dp0..\.."
  if not exist "%Git_Root%\LCM_Inventory" (
    echo [ERROR] Target repository not found relative to Git_Root: %Git_Root%
    exit /b 1
  )
  ```

### Component 2: Audit and Clean Hand-Crafted Trampolines
- Scan `LCM_Inventory/Cmd/*.cmd` and update any manually written trampolines containing fallback logic.

### Component 3: Regenerate Managed Trampolines
- Run `Update-ToolCatalog.ps1` to re-emit all trampolines with the updated preamble.

## 4. Verification Plan
- Unit and regression tests to verify that trampolines function properly in place.
- Verify that calling a trampoline from an invalid or unmounted context fails closed rather than jumping to `D:\Git_Repositories`.
- Pass 6/6 LCM general readiness quality gates.
