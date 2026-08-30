# Walkthrough: Proposal #26 (CR-2026-037 / CRP-2026-008) - Workspace Inventory Viewer Interactive Actions Suite, Non-Git Visibility, and Data Versioning Exemption

**Proposal ID**: #26  
**Change Request ID**: `CR-2026-037`  
**Bundle ID**: `CRP-2026-008-Workspace_Inventory-v7.1.1-Inventory-Viewer-Interactive-Actions-and-Data-Versioning-Exemption`  
**Origin Repository**: `Workspace_Inventory`  
**Author**: rgbig  
**Status**: In-Progress  
**Date**: 2026-08-30  

---

## 1. Summary of Changes
1. **Interactive Directory Actions** in [`Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1`](file:///d:/Git_Repositories/Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1):
   * Added action buttons for Open in Explorer, Onboard, Un-Git, Rename, and Delete.
   * Full inclusion of `.lcd` and all non-Git folders.
2. **Data Versioning Exemption Codified** in [`ReviewCommitGovernancePolicy.md`](file:///d:/Git_Repositories/.agents/rules/ReviewCommitGovernancePolicy.md):
   * Excluded routine data/telemetry updates in `Workspace_Inventory` from triggering version bumps.

---

## 2. Validation
* Verified interactive browser actions.
* Passed `Test-WorkspaceReadiness.ps1`.
