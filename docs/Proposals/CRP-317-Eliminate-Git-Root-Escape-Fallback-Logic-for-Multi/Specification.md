# Change Request Proposal: CRP-317

```yaml
CRP-ID: CRP-317
Title: Eliminate Git_Root Escape Fallback Logic for Multi-Workspace and Sandbox Isolation
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-10 20:18:32
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Gate-1: Accepted (2026-11-10 20:35:00)
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
Remove all hardcoded `Git_Root` fallback and escape logic (specifically lines defaulting to `D:\Git_Repositories` when paths are not found or defined) from trampolines (`Cmd/*.cmd`) and scripts across LCM. This is a foundational prerequisite for the upcoming Multi-Workspace and Sandbox architecture, where the active workspace drive and repository structure is defined by an HKLM registry structure (e.g. `Sandbox n`) rather than fixed paths on `D:`. Any fallback to `D:\Git_Repositories` breaks sandbox isolation and leads to contamination or failure.

---

## 2. Gate 0 Contract

### Target State
1. Command trampolines (`Cmd/*.cmd`) rely strictly on deterministic parent-relative discovery:
   - Root is `%~dp0..\..` (two levels up from `LCM_Inventory\Cmd\`).
   - Prohibit all escape lines such as:
     `if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"`
2. If `Git_Root` or target components are missing from the designated path, the launcher must fail closed with an explicit error rather than silently falling back to `D:\Git_Repositories`.
3. `Update-ToolCatalog.ps1`: Update `$gitRootPreamble` to remove the fallback check and fail cleanly if the local workspace structure cannot be resolved.
4. Prepare scripts and modules for HKLM/Sandbox workspace drive redirection without static `D:\Git_Repositories` escape defaults.

### Invariants and Exit Criteria
- **Zero Fallback Invariant**: No trampoline or script shall silently redirect execution to `D:\Git_Repositories` when run within an alternate drive, directory, or sandbox workspace.
- **Fail-Closed Invariant**: Missing target scripts fail immediately with a non-zero exit code and an informative error message.
- **AST and Readiness Quality Gate Pass**: All modified files pass AST parsing and 6/6 LCM general readiness quality gates.

### Explicit Non-Goals
- Full implementation of the HKLM "Sandbox n" registry mechanism itself (which is tracked under a dedicated future CRP). CRP-317 focuses strictly on removing the fallback/escape logic and ensuring trampolines and scripts are clean and ready.

---

## 3. Technical Requirements & Invariants
- Update `$gitRootPreamble` in `LCM_Inventory/tools/Update-ToolCatalog.ps1`:
  From:
  ```cmd
  if not defined Git_Root set "Git_Root=%~dp0..\.."
  if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
  ```
  To:
  ```cmd
  if not defined Git_Root set "Git_Root=%~dp0..\.."
  if not exist "%Git_Root%\LCM_Inventory" (
    echo [ERROR] LCM_Inventory not found relative to Git_Root: %Git_Root%
    exit /b 1
  )
  ```
- Regenerate all managed trampolines via `Update-ToolCatalog.ps1`.
- Audit manually created trampolines and scripts for static `D:\Git_Repositories` fallback logic.
