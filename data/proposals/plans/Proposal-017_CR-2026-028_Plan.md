# Implementation Plan - Proposal #17 (CR-2026-028)
## Resolve Broken Path Delegation in Numbered Legacy Alias Wrappers (@21-FixMouseFlickerInvariants.ps1 & @20-KillLogitechUpdateFull.ps1)

### 1. Goal Description
Fix runtime path resolution failure when launching legacy alias tools `FixMouseFlicker` (`@21-FixMouseFlickerInvariants.ps1`) and `KillLogitechFull` (`@20-KillLogitechUpdateFull.ps1`) from `Show-Tools` web explorer or elevated shell. Currently, the wrappers evaluate `$PSScriptRoot\..\..\tools\Set-MouseFlickerInvariants.ps1` which resolves to non-existent `D:\tools\...` when executed from `D:\Git_Repositories\LCM_Tools`.

---

### 2. Proposal Registry Entry
- **Proposal ID**: `#17`
- **CR ID**: `CR-2026-028`
- **Origin Repo**: `Root (tools) / SystemConfiguration`
- **State**: `suggested`
- **Progress State**: `undecided`
- **Title**: *Resolve Broken Path Delegation in Numbered Legacy Alias Wrappers (@21-FixMouseFlickerInvariants.ps1 & @20-KillLogitechUpdateFull.ps1)*
- **Plan Path**: `LCM_Inventory/data/proposals/plans/Proposal-017_CR-2026-028_Plan.md`
- **Walkthrough Path**: `LCM_Inventory/data/proposals/plans/Proposal-017_CR-2026-028_Walkthrough.md`

---

### 3. Root Cause Analysis
1. In `tools\@21-FixMouseFlickerInvariants.ps1`:
   - Line 41-44 attempts:
     ```powershell
     $target = Join-Path $PSScriptRoot 'Set-MouseFlickerInvariants.ps1'
     if (-not (Test-Path -LiteralPath $target)) {
       $target = Join-Path $PSScriptRoot '..\..\tools\Set-MouseFlickerInvariants.ps1'
     }
     ```
   - When executed from `D:\Git_Repositories\LCM_Tools`, `$PSScriptRoot` is `D:\Git_Repositories\LCM_Tools`.
   - `D:\Git_Repositories\LCM_Tools\Set-MouseFlickerInvariants.ps1` does not exist (the canonical implementation is in `SystemConfiguration\Source\Set-MouseFlickerInvariants.ps1`).
   - The fallback path `..\..\tools\Set-MouseFlickerInvariants.ps1` resolves to `D:\tools\Set-MouseFlickerInvariants.ps1`, which throws a CommandNotFoundException upon invocation (`& $target @runnerArgs`).
2. In `tools\@20-KillLogitechUpdateFull.ps1`:
   - Identical defect delegating to `Kill-LogitechUpdate.ps1`.
3. In `SystemConfiguration\Source\@21-FixMouseFlickerInvariants.ps1` and `SystemConfiguration\Source\@20-KillLogitechUpdateFull.ps1`:
   - Contains the same fallback logic (`..\..\tools\...`) which breaks if target files are not located in `tools/`.

---

### 4. Proposed Solution & Architecture
Implement robust, multi-candidate path resolution with dynamic fallback:
```powershell
$targetCandidates = @(
  (Join-Path $PSScriptRoot 'Set-MouseFlickerInvariants.ps1'),
  (Join-Path $PSScriptRoot '..\SystemConfiguration\Source\Set-MouseFlickerInvariants.ps1'),
  (Join-Path $PSScriptRoot '..\..\SystemConfiguration\Source\Set-MouseFlickerInvariants.ps1'),
  'D:\Git_Repositories\SystemConfiguration\Source\Set-MouseFlickerInvariants.ps1'
)
$target = $targetCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $target) {
  throw "Cannot locate canonical Set-MouseFlickerInvariants.ps1 in candidate paths."
}
```
Apply the identical pattern to `@20-KillLogitechUpdateFull.ps1` targeting `Kill-LogitechUpdate.ps1`.
Sync and re-generate `tool_catalog.json` and `tools\Cmd\*.cmd` via `Update-ToolCatalog.ps1` and verify symlink synchronization with `Sync-ToolSymlinks.ps1`.

---

### 5. Verification Plan
1. **Direct Execution**:
   - `pwsh -File tools\@21-FixMouseFlickerInvariants.ps1 -h`
   - `pwsh -File tools\@20-KillLogitechUpdateFull.ps1 -h`
2. **Interactive UI / Desktop Launch**:
   - Test execution from `Show-Tools` web interface (Zen browser) with options (`-ShowAll`, `-TraceMode`).
3. **Automated Quality Gate**:
   - Run `LCM_AI\tools\Test-WorkspaceReadiness.ps1` to verify clean pass across all repositories.
