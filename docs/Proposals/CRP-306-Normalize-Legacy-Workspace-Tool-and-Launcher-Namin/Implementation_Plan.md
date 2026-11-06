# Implementation Plan: CRP-306 - Normalize Legacy Workspace Tool and Launcher Naming to LCM_ Prefix

## 1. Executive Summary & Problem Context
Systematic renaming of all `Workspace*` operational scripts, modules, and `.cmd` launchers in `LCM_Inventory` to use the explicit `LCM_` prefix (e.g., `Invoke-LCM_Push.ps1`, `LCM_Push.cmd`, `LCM_PushEligibility.psm1`), followed by updating all internal references, ToolCatalog definitions, and interactive macros.

## 2. Gate 0 Traceability
* **Phase 1: File Renames**: Rename scripts in `LCM_Inventory/tools/`, modules in `LCM_Inventory/modules/`, and launchers in `LCM_Inventory/Cmd/`.
* **Phase 2: Internal Caller Reconciliation**: Update import paths (e.g. `LCM_PushEligibility.psm1`), script paths in launchers, and references in other tools.
* **Phase 3: Catalog & Macro Synchronization**: Update `tool_catalog.json`, `Update-ToolCatalog.ps1`, and `macro-definitions.md`.
* **Phase 4: Quality Gate & AST Verification**: Run AST syntax checks on all modified/renamed files and execute `Invoke-LCM_Push.ps1 -DryRun`.

## 3. Proposed Changes

### Component 1: Core Tools & Modules Renaming
- Rename 12 operational scripts in `LCM_Inventory/tools/`:
  - `Invoke-WorkspacePush.ps1` -> `Invoke-LCM_Push.ps1`
  - `Invoke-WorkspaceMaintenance.ps1` -> `Invoke-LCM_Maintenance.ps1`
  - `Invoke-WorkspaceGoodMorning.ps1` -> `Invoke-LCM_GoodMorning.ps1`
  - `Invoke-WorkspaceGoodNight.ps1` -> `Invoke-LCM_GoodNight.ps1`
  - `Invoke-WorkspaceAudit.ps1` -> `Invoke-LCM_Audit.ps1`
  - `Show-WorkspaceReadiness.ps1` -> `Show-LCM_Readiness.ps1`
  - `Show-WorkspaceInventoryApp.ps1` -> `Show-LCM_InventoryApp.ps1`
  - `Test-WorkspaceReadiness.ps1` -> `Test-LCM_Readiness.ps1`
  - `Test-WorkspaceDrift.ps1` -> `Test-LCM_Drift.ps1`
  - `Create-WorkspaceBaseline.ps1` -> `Create-LCM_Baseline.ps1`
  - `Get-WorkspaceRepositories.ps1` -> `Get-LCM_Repositories.ps1`
  - `Publish-WorkspaceProposalBundles.ps1` -> `Publish-LCM_ProposalBundles.ps1`
- Rename 3 modules in `LCM_Inventory/modules/`:
  - `WorkspacePushEligibility.psm1` -> `LCM_PushEligibility.psm1`
  - `WorkspaceCM.psm1` -> `LCM_CM.psm1`
  - `LcmWorkspaceContext.psm1` -> `LCM_Context.psm1`

### Component 2: Launchers & Catalog Updates
- Rename 12 `.cmd` launchers in `LCM_Inventory/Cmd/` and update their target script paths.
- Update `tool_catalog.json` and `Update-ToolCatalog.ps1` entries to register the `LCM_` commands with backward-compatible aliases for the legacy `Workspace` names.

## 4. Verification Plan
- Automated AST syntax verification (`RULE-PS-021`) on all modified scripts.
- Execution of `Invoke-LCM_Push.ps1 -DryRun` and `Update-ToolCatalog.ps1`.
- Gate 2 Beyond Compare (BCR) review before commit.
