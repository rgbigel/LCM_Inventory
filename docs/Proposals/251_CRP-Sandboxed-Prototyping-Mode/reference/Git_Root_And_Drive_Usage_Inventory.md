# Reference Material: Comprehensive Git_Root and Drive Usage Inventory across LCM
Proposal: CRP-251 (Sandboxed Prototyping Mode)
Author: Rolf, LCM_AI Architecture
Date: 2026-11-10 20:33:00
Status: Authoritative Reference Document

---

## 1. Executive Summary & Purpose

This reference document catalogs all locations, patterns, and dependencies across the Lifecycle Model (LCM) workspace where `Git_Root` (or the physical drive `D:`) is referenced.

This inventory provides the foundational architectural substrate for **CRP-251 (Sandboxed Prototyping Mode)** and **CRP-317 (Eliminate Git_Root Escape Fallback Logic)**. The objective is to decouple all hardcoded drive/root assumptions, enabling the LCM framework to seamlessly run within:
1. **Live Production Workspace** (`D:\Git_Repositories`, live machine registry).
2. **Sandboxed Prototyping Workspaces** (e.g. simulated drive `S:`, Macrium writable mount `F:`, or directory sandbox `Sandbox n`), dynamically defined via an HKLM structure without cross-workspace escape contamination.

---

## 2. Quantitative Scan Summary

| Category / Extension | File Count | Match Count | Primary Nature of Reference |
|:---|:---|:---|:---|
| **Batch Trampolines (`.cmd`)** | ~800 | 818 | Preamble definition (`if not defined Git_Root set "Git_Root=%~dp0..\.."`) and escape fallback (`set "Git_Root=D:\Git_Repositories"`). |
| **PowerShell Scripts (`.ps1`)** | 82 | 216 | Default parameters (`$WorkspaceRoot = 'D:\Git_Repositories'`), root anchoring, daemon runner arguments. |
| **PowerShell Modules (`.psm1`)** | 22 | 82 | Machine registry extraction (`LCM_Context.psm1`), workspace resolution (`ProposalManager.psm1`, `LcmToolCatalog.psm1`). |
| **Python Scripts (`.py`)** | 12 | 29 | Environment queries (`os.environ.get('Git_Root', 'D:/Git_Repositories')`) and hardcoded script paths. |
| **Configuration (`.json`)** | 28 | 499 | Catalog paths, app root mappings, MCP server declarations (`.mcp.json`). |
| **Total Code / Script Matches** | **148** | **1,644** | Across all active code, modules, tools, and trampolines. |

---

## 3. Detailed Architectural Categorization & Decoupling Strategy

### Category A: The Machine Registry Anchor (HKLM)
- **Primary Source File**: [`LCM_Inventory/modules/LCM_Context.psm1`](file:///D:/Git_Repositories/LCM_Inventory/modules/LCM_Context.psm1)
- **Management Tool**: [`LCM_Inventory/tools/Set-GitRoot.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Set-GitRoot.ps1) (31 references)
- **Current Behavior**:
  `LCM_Context.psm1` reads `Git_Root` exclusively from:
  `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\Git_Root`
  Validates that the path exists, is absolute, and contains `LCM_Inventory`.
- **Sandbox Decoupling Blueprint**:
  - Replace the single flat string key with an HKLM registry structure:
    `HKLM:\SOFTWARE\LCM\Workspaces\Current` -> pointing to `ActiveProfile` (`Live`, `Sandbox-1`, `Sandbox-2`).
    `HKLM:\SOFTWARE\LCM\Workspaces\Profiles\<ProfileName>\RootPath`
  - When in a Sandbox, the profile determines the workspace drive and root path cleanly without system-wide collisions.

---

### Category B: Command Trampolines (`Cmd/*.cmd`)
- **Location**: `LCM_Inventory/Cmd/*.cmd` (818 matches across all short-name trampolines).
- **Generator**: [`LCM_Inventory/tools/Update-ToolCatalog.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1) (lines 1194–1215).
- **Current Preamble Pattern**:
  ```cmd
  @echo off
  if not defined Git_Root set "Git_Root=%~dp0..\.."
  if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/..." %*
  ```
- **Hazard for Sandbox**:
  The line `if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"` is a dangerous escape hatch. If a sandbox drive or folder structure fails to resolve, it silently escapes back to `D:\Git_Repositories`, risking production state corruption.
- **Decoupling Action (CRP-317)**:
  - Eliminate the second line completely.
  - Fail closed: If `%~dp0..\..\LCM_Inventory` does not exist, abort with exit code 1.
  - Trampolines remain 100% relative to their containing workspace.

---

### Category C: Core Governance Modules (`LCM_Inventory/modules/*`)

| Module | Matches | Key Functions / Code Lines | Decoupling Requirement |
|:---|:---|:---|:---|
| **`LCM_Context.psm1`** | 6 | `Get-LCMContext`, `Resolve-WorkspacePath` | Central router for resolving current workspace root; will read HKLM sandbox profile. |
| **`ProposalManager.psm1`** | 12 | `Get-ProposalStorePath`, `New-LCM_Proposal` | Proposal bundle and review ledger path resolution. Must anchor to context root. |
| **`LcmToolCatalog.psm1`** | 9 | `Get-LcmToolCatalog`, `Update-LcmToolIntentCall` | Tool execution paths and intent mappings. |
| **`AdminMode.psm1`** | 7 | `Assert-AdminModeAuthorization` | Elevates commands while maintaining relative workspace paths. |
| **`AnalysisGovernance.psm1`** | 8 | `Get-AnalysisContext`, log routing | Analysis state logs and artifact generation. |
| **`LcmProgressAtom.psm1`** | 1 | `$script:WorkspaceRoot = if (...) else { 'D:\Git_Repositories' }` | Purge `'D:\Git_Repositories'` default; query `LCM_Context`. |
| **`InboxWatcher.psm1`** | 5 | Two-phase ACK mirrors and inbox queue | Decouple local mirror path from hardcoded `D:`. |
| **`LCM_CM.psm1`** | 2 | CM ledger and change management | Relative root resolution. |

---

### Category D: Tools with Default Parameter Values (`LCM_Inventory/tools/*`)
Many tools declare:
```powershell
param(
  [string]$WorkspaceRoot = 'D:\Git_Repositories'
)
```
or
```powershell
$workspaceRoot = if ($env:Git_Root) { $env:Git_Root } else { 'D:\Git_Repositories' }
```
**Files Affected**:
1. [`Update-ToolCatalog.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1#L78): `$workspaceRoot = 'D:\Git_Repositories'`
2. [`Show-LcmActiveLauncher.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Show-LcmActiveLauncher.ps1): 19 occurrences of path lookups.
3. [`Format-LcmMarkdownDiagrams.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1): 11 occurrences.
4. [`Search-Everything.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Search-Everything.ps1): 6 occurrences.
5. [`Sync-ToolSymlinks.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Sync-ToolSymlinks.ps1): 6 occurrences.
6. [`Test-DocumentationCompleteness.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Test-DocumentationCompleteness.ps1): 3 occurrences.
7. [`Test-GeneralReadiness.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Test-GeneralReadiness.ps1): 1 occurrence.
8. [`Invoke-MacriumDailyBcrBaseline.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1): candidate comparisons against `D:\Git_Repositories`.

**Decoupling Strategy**:
Replace static defaults with dynamic resolution via `(Get-LCMContext).GitRoot` or `$PSScriptRoot/../..`.

---

### Category E: Child Repositories

1. **`BackgroundModifier` (12 modules)**:
   - `Modules\Constants.psm1`, `Modules\PathTools.psm1`, `Modules\RuntimeStateTools.psm1`, etc.
   - All query `$env:Git_Root`.
   - **Status**: Clean; they do not hardcode `D:\Git_Repositories` but rely on the environment variable, which the Sandbox will set.
2. **`HaSSD06` & `HaSSD06_Inventory` (25 matches)**:
   - Python tools (`extract_ha_update_crps.py`, `deep_device_scan.py`, `build_offline_docs.py`).
   - Use `os.environ.get('Git_Root', 'D:/Git_Repositories')`.
   - **Decoupling**: Remove `'D:/Git_Repositories'` fallback; fail or query sandbox profile.
3. **`LCM_Shared` (6 matches)**:
   - `Modules\PrivatePaths.psm1`: Private token stores.
   - `Modules\VolumeAtoms.psm1`: Mount and volume operations.
4. **`LCM_Supervision` & `LCM_Tools` (10 matches)**:
   - `Invoke-SupervisionRunner.ps1`, `Sync-LCMResearchSnapshot.ps1`.
5. **`TimeStamper` & `VolumeInventory` (5 matches)**:
   - Installer and volume recovery scripts.

---

### Category F: External Tool Integrations & IDE Configurations
1. **`.mcp.json`**:
   Configured in root workspace for Model Context Protocol servers:
   ```json
   "homeassistant-readonly": {
     "command": "python",
     "args": ["D:\\Git_Repositories\\HaSSD06\\mcp_ha_readonly.py"]
   }
   ```
   **Sandbox Implication**: For a sandbox instance running separate MCP servers, paths must resolve relative to the sandbox root.
2. **`apps.json`**:
   `LCM_Inventory/data/catalog/apps.json` defines child repositories and constituent manifests.
   All constituent paths are relative (`LCM_Inventory`, `LCM_AI`, `HaSSD06`), making them clean for sandbox usage.

---

## 4. Synthesis & Recommendations for Sandbox Architecture (CRP-251)

1. **Rule of Deterministic Parent Resolution**:
   Any tool or trampoline running from inside a repository must determine the workspace root by walking up its own directory tree (`%~dp0..\..` in batch, or `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` in PowerShell) instead of querying machine-wide state or assuming `D:`.
2. **HKLM Profile Switcher**:
   When launching a sandboxed workspace session:
   - The sandbox launcher registers `HKLM\SOFTWARE\LCM\ActiveWorkspace = S:\Git_Repositories` (or ephemeral environment block).
   - All tools querying `Get-LCMContext` automatically inherit `S:\Git_Repositories` without code changes.
3. **Zero Fallback Invariant (CRP-317)**:
   Under no circumstances shall any script or trampoline fall back to `D:\Git_Repositories` when a local path is missing. If the target does not exist in the active workspace/sandbox, it must fail closed immediately.

