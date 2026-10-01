# Plan: Proposal #26 (CR-2026-037 / CRP-2026-008) - Workspace Inventory Viewer Interactive Actions Suite, Non-Git Visibility, and Data Versioning Exemption

**Proposal ID**: #26  
**Change Request ID**: `CR-2026-037`  
**Bundle ID**: `CRP-2026-008-LCM_Inventory-v7.1.1-Inventory-Viewer-Interactive-Actions-and-Data-Versioning-Exemption`  
**Origin Repository**: `LCM_Inventory`  
**Author**: rgbig  
**Status**: In-Progress  
**Date**: 2026-08-30  

---

## 1. Problem Statement
1. The Workspace Inventory Viewer lacked interactive row actions (Open in Explorer, Delete, Rename, Onboarding, Un-Git).
2. The `.lcd` platform repository and non-Git infrastructure folders were missing or insufficiently prominent in the web table view.
3. Routine data ledger accounting in `LCM_Inventory` (such as `proposals.json`, `inventory.json`, `cm_activity.log`) was triggering unnecessary semantic version increments.

---

## 2. Proposed Changes

1. **`LCM_Inventory/tools/Show-WorkspaceInventoryApp.ps1` & `WORKSPACE_INVENTORY_VIEWER.html`**:
   * Add interactive action buttons to each repository row:
     * **📂 Open**: Open in Windows Explorer via REST daemon.
     * **🛡️ Onboard**: Execute LCM onboarding wizard.
     * **🚫 Un-Git**: Strip `.git` metadata after confirmation.
     * **✏️ Rename**: Prompt for new name and execute rename.
     * **🗑️ Delete**: Safely remove folder with confirmation.
   * Add full visibility for `.lcd`, `.agents`, `.copilot`, and all non-Git folders.
   * Add category filter tabs (`All`, `Governed`, `Standard Git`, `Non-Git / Infrastructure`).
   * Add Single-Instance `BroadcastChannel` tab coordination.

2. **`.agents/rules/ReviewCommitGovernancePolicy.md`**:
   * Codify the Data Versioning Exemption in `RULE-REV-007`.

3. **`LCM_Inventory/modules/WorkspaceCM.psm1`**:
   * Ensure `.lcd` is audited with proper platform classification.

---

## 3. Verification Plan
* Run `Show-WorkspaceInventoryApp.ps1` and test interactive action dispatches.
* Verify `.lcd` is present with version in the browser table.
* Run `Test-WorkspaceReadiness.ps1`.
