# Implementation Plan: CRP-176 Workspace AI Super-Controller (Option A)

## Proposed Changes

### 1. Navigation Dispatcher & CLI Trampoline
- Create `LCM_Inventory/tools/Show-SuperController.ps1`:
  - Parameter `-Subsystem` (defaults to `ALL`, supports all taxonomy subsystems).
  - Parameter `-Tool` (`All`, `Tools` / `ToolsExplorer`, `CM` / `ShowCM`).
  - Parameter `-CliMode` (terminal output).
  - Launches Zen Browser (`D:\Tools\Zen Browser\zen.exe`) with `--new-window` via `Invoke-InteractiveDesktop.ps1`.
- Create `.lcm/Cmd/SuperController.cmd` trampoline.

### 2. IDE Answer Box Card Widget
- Standardized markdown action card embedded into assistant responses:
  - Subsystem scope badges.
  - One-click launcher commands for ToolsExplorer and ShowCM.
  - Zero unnecessary browser windows.

---

## Verification Plan
- Run `pwsh LCM_Inventory/tools/Show-SuperController.ps1 -Help`.
- Run `pwsh LCM_Inventory/tools/Show-SuperController.ps1 -CliMode -Subsystem LCM`.
- Confirm `SuperController.cmd` launches without syntax errors.
