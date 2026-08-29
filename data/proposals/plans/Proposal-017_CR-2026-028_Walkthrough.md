# Walkthrough - Proposal #17 (CR-2026-028)
## Resolve Broken Path Delegation in Numbered Legacy Alias Wrappers (@21-FixMouseFlickerInvariants.ps1 & @20-KillLogitechUpdateFull.ps1)

### 1. Summary of Changes
Fixed runtime path resolution failure when invoking legacy alias wrappers from `Show-Tools` web explorer dashboard or CLI.
- Replaced brittle relative path fallback (`..\..\tools\...`) with robust multi-candidate resolution across:
  - Local directory (`$PSScriptRoot`)
  - Subsystem relative paths (`..\SystemConfiguration\Source`, `..\..\SystemConfiguration\Source`)
  - Absolute workspace root fallback (`D:\Git_Repositories\SystemConfiguration\Source`)
- Updated version metadata headers to `2.1.1` (Date `2026-08-29`) conforming to `RULE-PS-008`.
- Synchronized tool catalog (`Update-ToolCatalog.ps1`) and dynamic NTFS symlinks (`Sync-ToolSymlinks.ps1`).

---

### 2. Files Modified
- [`tools/@21-FixMouseFlickerInvariants.ps1`](file:///D:/Git_Repositories/tools/@21-FixMouseFlickerInvariants.ps1)
- [`SystemConfiguration/Source/@21-FixMouseFlickerInvariants.ps1`](file:///D:/Git_Repositories/SystemConfiguration/Source/@21-FixMouseFlickerInvariants.ps1)
- [`tools/@20-KillLogitechUpdateFull.ps1`](file:///D:/Git_Repositories/tools/@20-KillLogitechUpdateFull.ps1)
- [`SystemConfiguration/Source/@20-KillLogitechUpdateFull.ps1`](file:///D:/Git_Repositories/SystemConfiguration/Source/@20-KillLogitechUpdateFull.ps1)
- [`tools/tool_catalog.json`](file:///D:/Git_Repositories/tools/tool_catalog.json)
- [`tools/README.md`](file:///D:/Git_Repositories/tools/README.md)
- [`Workspace_Inventory/data/proposals/proposals.json`](file:///D:/Git_Repositories/Workspace_Inventory/data/proposals/proposals.json)

---

### 3. Validation Results
- Direct invocation help test (`pwsh tools/@21-FixMouseFlickerInvariants.ps1 -h`): **PASSED** (delegates cleanly to `Set-MouseFlickerInvariants.ps1`).
- Direct invocation help test (`pwsh tools/@20-KillLogitechUpdateFull.ps1 -h`): **PASSED** (delegates cleanly to `Kill-LogitechUpdate.ps1`).
- CMD trampoline test (`tools/Cmd/FixMouseFlicker.cmd -h`): **PASSED**.
- Tool catalog synchronization (`Update-ToolCatalog.ps1`): **PASSED** (141 tools, 141 launchers).
- Dynamic symlink sync (`Sync-ToolSymlinks.ps1`): **PASSED** (0 orphaned links).
- Quality gate (`Workspace_AI/tools/Test-WorkspaceReadiness.ps1`): **PASSED** (`Workspace_AI readiness self-test: OK`).
