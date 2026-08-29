# Implementation Plan - Proposal #20 (CR-2026-031)
## Consolidate LCD Platform Engine into Encapsulated `.lcd` Structure with `tools/internal` and `tools/links` Separation

### 1. Goal Description
Encapsulate the core LCD platform engine into a dedicated `.lcd/` standard directory structure under `D:\Git_Repositories\.lcd`, separating native engine code (`.lcd\tools\internal\`) from dynamic child repository symlinks (`.lcd\tools\links\`), updating child repository rule junctions, migrating `%PATH%` to `.lcd\Cmd`, and preserving IDE rule discovery via a root compatibility junction.

---

### 2. Proposal Registry Entry
- **Proposal ID**: `#20`
- **CR ID**: `CR-2026-031`
- **Origin Repo**: `Root / .lcd`
- **State**: `approved`
- **Progress State**: `in_progress`
- **Title**: *Consolidate LCD Platform Engine into Encapsulated .lcd Structure with tools/internal and tools/links Separation*
- **Plan Path**: `Workspace_Inventory/data/proposals/plans/Proposal-020_CR-2026-031_Plan.md`
- **Walkthrough Path**: `Workspace_Inventory/data/proposals/plans/Proposal-020_CR-2026-031_Walkthrough.md`

---

### 3. Architecture Specification

```text
D:\Git_Repositories\
  ├── .lcd\
  │     ├── .agents\
  │     │     └── rules\               <── Authoritative Governance Rules Hub (v6.1.1+)
  │     ├── Cmd\                       <── Global .cmd trampolines in %PATH%
  │     ├── config\                    <── lcm_config.json & manifest descriptors
  │     ├── docs\                      <── Tripartite Specifications & Platform Docs
  │     ├── install\                   <── Platform Installation & Deployment Runbook
  │     ├── modules\                   <── Core PowerShell Modules (LcmToolCatalog.psm1, LcmDaemonCore.psm1)
  │     ├── tools\
  │     │     ├── internal\            <── Core Engine Scripts (Git-tracked)
  │     │     └── links\               <── Dynamic Child Symlinks (.gitignored)
  │     ├── tests\                     <── Platform Verification Suite
  │     ├── logs\                      <── Execution Telemetry (.gitignored)
  │     └── scratch\                   <── Ephemeral Scratchpad (.gitignored)
  │
  ├── .agents                          <── Root NTFS Junction -> .lcd\.agents (IDE Compatibility)
  ├── Workspace_AI\                    <── Maintainer & Orchestrator
  ├── Workspace_Inventory\             <── CM Ledger & Review Receipts
  └── [Child Repositories]\            <── Domain Projects (.agents\rules -> .lcd\.agents\rules)
```

---

### 4. Migration & Implementation Steps

1. **Create `.lcd\` Hierarchy**:
   - Provision `.lcd\.agents\rules`, `.lcd\Cmd`, `.lcd\config`, `.lcd\docs`, `.lcd\install`, `.lcd\modules`, `.lcd\tools\internal`, `.lcd\tools\links`, `.lcd\tests`, `.lcd\logs`, `.lcd\scratch`.
2. **Move/Copy Rules**:
   - Move `.agents\rules\` to `.lcd\.agents\rules\`.
   - Create root compatibility junction `D:\Git_Repositories\.agents` $\rightarrow$ `D:\Git_Repositories\.lcd\.agents`.
3. **Move Modules**:
   - Move `tools\modules\*` to `.lcd\modules\`.
4. **Move Internal Platform Tools**:
   - Move platform scripts (`Update-ToolCatalog.ps1`, `Sync-ToolSymlinks.ps1`, `LcmDesktopDaemon.ps1`, `Show-Tools.ps1`, `Show-ToolIndex.ps1`, etc.) into `.lcd\tools\internal\`.
5. **Update Engine Logic (`Update-ToolCatalog.ps1` & `Sync-ToolSymlinks.ps1`)**:
   - Update scan paths to discover tools in child repositories and generate symlinks in `.lcd\tools\links\`.
   - Update CMD generator to output trampolines into `.lcd\Cmd\`.
6. **Update Child Repository Junctions**:
   - Update `.agents\rules` junction in every child repository to target `D:\Git_Repositories\.lcd\.agents\rules`.
7. **Update Environment `%PATH%`**:
   - Register `D:\Git_Repositories\.lcd\Cmd` in user `%PATH%`.
8. **Run Dynamic Synchronization**:
   - Run `.lcd\tools\internal\Update-ToolCatalog.ps1`.
   - Run `.lcd\tools\internal\Sync-ToolSymlinks.ps1`.
9. **Automated Verification**:
   - Run `Test-LCMRuleHealth.ps1`.
   - Run `Test-WorkspaceReadiness.ps1`.
