# Change Request Proposal: CRP-306

```yaml
CRP-ID: CRP-306
Title: Normalize Legacy Workspace Tool and Launcher Naming to LCM_ Prefix
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-06 10:30:13
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent

Following the clean alignment of remote repositories and local container directories to the authoritative `LCM_*` taxonomy, legacy tool scripts, modules, and `.cmd` launchers carrying the `Workspace` prefix (`Invoke-WorkspacePush.ps1`, `WorkspacePush.cmd`, `WorkspacePushEligibility.psm1`, etc.) represent an obsolete naming artifact.

Per operator directive, this proposal systematically normalizes all legacy `Workspace` prefixed operational tools, modules, and command wrappers in `LCM_Inventory` to use the explicit **`LCM_`** identifier (e.g., `Invoke-LCM_Push.ps1`, `LCM_Push.cmd`, `LCM_PushEligibility.psm1`).

---

## 2. Gate 0 Contract

### Target State
1. All 12 primary `Workspace*` operational tools under [`LCM_Inventory/tools/`](file:///D:/Git_Repositories/LCM_Inventory/tools/) are renamed to `*LCM_*`.
2. All 3 supporting `Workspace*` modules under [`LCM_Inventory/modules/`](file:///D:/Git_Repositories/LCM_Inventory/modules/) are renamed to `LCM_*`.
3. All command launchers under [`LCM_Inventory/Cmd/`](file:///D:/Git_Repositories/LCM_Inventory/Cmd/) are renamed to reflect the `LCM_` nomenclature.
4. Internal tool references, [`tool_catalog.json`](file:///D:/Git_Repositories/LCM_Inventory/config/tool_catalog.json), [`Update-ToolCatalog.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1), and interactive macros in [`macro-definitions.md`](file:///D:/Git_Repositories/.agents/rules/macro-definitions.md) are updated to point to the new names while preserving existing command shortcuts (`PUSH`, `GoodMorning`, `GoodNight`, etc.).

### Invariants and Exit Criteria
* **Invariant 1**: No functional logic regressions; each renamed tool and launcher maintains 100% parameter and operational parity.
* **Invariant 2**: Pre-handoff AST syntax verification (`RULE-PS-021`) passes with zero errors across all renamed and updated scripts.
* **Invariant 3**: Backward-compatible entry-point shims or aliases are cataloged so existing desktop shortcuts and automated hooks do not fault.
* **Invariant 4**: `Update-ToolCatalog.ps1` runs cleanly and updates catalog entries to reflect the new primary script paths.

### Explicit Non-Goals
* Cause no havoc; do not modify unrelated scripts in external repositories.
* Do not alter the fundamental push, review, or readiness logic beyond the naming refactoring.

---

## 3. Nomenclature Mapping Matrix

### 3.1 Primary Tools (`LCM_Inventory/tools/`)
| Current Name | Target Name (`LCM_` Standard) |
| :--- | :--- |
| `Invoke-WorkspacePush.ps1` | **`Invoke-LCM_Push.ps1`** |
| `Invoke-WorkspaceMaintenance.ps1` | **`Invoke-LCM_Maintenance.ps1`** |
| `Invoke-WorkspaceGoodMorning.ps1` | **`Invoke-LCM_GoodMorning.ps1`** |
| `Invoke-WorkspaceGoodNight.ps1` | **`Invoke-LCM_GoodNight.ps1`** |
| `Invoke-WorkspaceAudit.ps1` | **`Invoke-LCM_Audit.ps1`** |
| `Show-WorkspaceReadiness.ps1` | **`Show-LCM_Readiness.ps1`** |
| `Show-WorkspaceInventoryApp.ps1` | **`Show-LCM_InventoryApp.ps1`** |
| `Test-WorkspaceReadiness.ps1` | **`Test-LCM_Readiness.ps1`** |
| `Test-WorkspaceDrift.ps1` | **`Test-LCM_Drift.ps1`** |
| `Create-WorkspaceBaseline.ps1` | **`Create-LCM_Baseline.ps1`** |
| `Get-WorkspaceRepositories.ps1` | **`Get-LCM_Repositories.ps1`** |
| `Publish-WorkspaceProposalBundles.ps1` | **`Publish-LCM_ProposalBundles.ps1`** |

### 3.2 Modules (`LCM_Inventory/modules/`)
| Current Name | Target Name |
| :--- | :--- |
| `WorkspacePushEligibility.psm1` | **`LCM_PushEligibility.psm1`** |
| `WorkspaceCM.psm1` | **`LCM_CM.psm1`** |
| `LcmWorkspaceContext.psm1` | **`LCM_Context.psm1`** |

### 3.3 Command Launchers (`LCM_Inventory/Cmd/`)
| Current Name | Target Name |
| :--- | :--- |
| `WorkspacePush.cmd` | **`LCM_Push.cmd`** |
| `WorkspaceMaintenance.cmd` | **`LCM_Maintenance.cmd`** |
| `WorkspaceGoodMorning.cmd` | **`LCM_GoodMorning.cmd`** |
| `WorkspaceGoodNight.cmd` | **`LCM_GoodNight.cmd`** |
| `WorkspaceAudit.cmd` | **`LCM_Audit.cmd`** |
| `ShowWorkspaceReadiness.cmd` | **`ShowLCM_Readiness.cmd`** |
| `ShowWorkspaceInventoryApp.cmd` | **`ShowLCM_InventoryApp.cmd`** |
| `TestWorkspaceReadiness.cmd` | **`TestLCM_Readiness.cmd`** |
| `TestWorkspaceDrift.cmd` | **`TestLCM_Drift.cmd`** |
| `CreateWorkspaceBaseline.cmd` | **`CreateLCM_Baseline.cmd`** |
| `GetWorkspaceRepositories.cmd` | **`GetLCM_Repositories.cmd`** |
| `PublishWorkspaceProposalBundles.cmd` | **`PublishLCM_ProposalBundles.cmd`** |

---

## 4. Verification Plan
1. **AST Syntax Validation**: Verify all renamed `.ps1` and `.psm1` files parse cleanly under `[System.Management.Automation.Language.Parser]`.
2. **Catalog Regeneration**: Run `Update-ToolCatalog.ps1` and confirm new tool paths are correctly indexed.
3. **Dry-Run Validation**: Execute `Invoke-LCM_Push.ps1 -DryRun` to ensure zero broken module imports or script references.
4. **Gate 2 Review**: Complete Beyond Compare (BCR) review before commit.
