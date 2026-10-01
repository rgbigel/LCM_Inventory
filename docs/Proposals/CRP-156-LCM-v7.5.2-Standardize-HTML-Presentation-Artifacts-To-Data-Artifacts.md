# Change Request Proposal: CRP-156

**Proposal ID**: `CRP-156`  
**Repository**: `LCM_Inventory` (Workspace-Wide Architecture)  
**Version**: `v7.5.2`  
**Date**: 2026-09-19  
**Status**: `COMPLETED` (`ACCEPTED`)  
**Author**: Operator Directive / CRP Intake  

---

## 1. Executive Summary

Historically, several interactive HTML viewers and dashboards (such as `SHOW_HA_INVENTORY.html`, `Entities_Inventory_HaSSD06.html`, `CM_CONTROL_HUB.html`, `WORKSPACE_INVENTORY_VIEWER.html`, `WORKSPACE_READINESS.html`, and `SUPERVISION_HUB.html`) were output to or stored within repository `docs/` directories.

Per [`DocumentationStandardsPolicy.md`](file:///D:/Git_Repositories/.agents/rules/DocumentationStandardsPolicy.md) (`RULE-DOC-001`), the `docs/` directory is strictly reserved for authoritative human-readable Markdown specifications (`Architecture.md`, `Requirements.md`, `Implementation.md`, `install/Installation.md`, `Proposals/`, and `README.md`). Dynamically generated HTML dashboards are **compiled presentation artifacts** derived from underlying JSON state files (`subsystem_inventory.json`, `inventory.json`, `supervision_catalog.json`). Storing these presentation artifacts in `docs/` creates severe Git churn and repository bloat on every inventory refresh.

This proposal standardizes all generated HTML presentation artifacts to **`data/artifacts/`**, relocates static HTML dashboard templates to **`assets/`**, untracks legacy HTML artifacts from Git across all repositories, and updates all `Show-*` and `Build-*` tools accordingly.

---

## 2. Architectural Standardization Matrix

| Repository | Component Type | Previous Path | New Standard Path |
| :--- | :--- | :--- | :--- |
| **`HaSSD06_Inventory`** | Presentation Artifact | `docs/SHOW_HA_INVENTORY.html` | `data/artifacts/SHOW_HA_INVENTORY.html` |
| **`HaSSD06_Inventory`** | Presentation Artifact | `docs/Entities_Inventory_HaSSD06.html` | `data/artifacts/Entities_Inventory_HaSSD06.html` |
| **`LCM_Inventory`** | UI Template | `docs/CM_CONTROL_HUB.html` | `assets/CM_CONTROL_HUB.html` |
| **`LCM_Inventory`** | UI Template | `docs/WORKSPACE_INVENTORY_VIEWER.html` | `assets/WORKSPACE_INVENTORY_VIEWER.html` |
| **`LCM_Inventory`** | Presentation Artifact | `docs/WORKSPACE_READINESS.html` | `data/artifacts/WORKSPACE_READINESS.html` |
| **`LCM_Supervision`** | UI Template & Artifact | `docs/SUPERVISION_HUB.html` | Template: `assets/SUPERVISION_HUB.html`<br/>Artifact: `data/artifacts/SUPERVISION_HUB.html` |

---

## 3. Implementation Details

1. **`HaSSD06_Inventory`**:
   - Updated `tools/Show-HaInventoryApp.ps1` and `tools/Build-HaInventoryViewer.ps1` to compile and output HTML files to `data/artifacts/`.
   - Untracked `docs/SHOW_HA_INVENTORY.html` and `docs/Entities_Inventory_HaSSD06.html` from Git (`git rm --cached`).
2. **`LCM_Inventory`**:
   - Moved static templates `CM_CONTROL_HUB.html` and `WORKSPACE_INVENTORY_VIEWER.html` to `assets/`.
   - Updated `tools/Show-CmControlHub.ps1`, `tools/Show-WorkspaceInventoryApp.ps1`, and `tools/Show-WorkspaceReadiness.ps1` to reference templates from `assets/` and render to `data/artifacts/`.
   - Untracked `docs/CM_CONTROL_HUB.html` and `docs/WORKSPACE_INVENTORY_VIEWER.html` from Git.
3. **`LCM_Supervision`**:
   - Moved `SUPERVISION_HUB.html` template to `assets/`.
   - Updated `tools/Show-SupervisionHub.ps1` to inject telemetry into `data/artifacts/SUPERVISION_HUB.html`.
   - Untracked `docs/SUPERVISION_HUB.html` from Git.
4. **BCR Universal Exclusions**:
   - Because `data/` is universally excluded in `Invoke-BeyondCompareReview.ps1` (v2.3.4), generated HTML artifacts in `data/artifacts/` will never pollute visual reviews or Git commits.

---

## 4. Verification

- Verified all tools execute cleanly and output to `data/artifacts/` without error.
- Verified `Test-RepoReadiness.ps1` in `HaSSD06_Inventory` and `LCM_Inventory` pass with 100% compliance.
