# Plan: Proposal #25 (CR-2026-036 / CRP-2026-007) - Single-Instance Control Hub Tab Lifecycle Coordination, Auto-Retirement, and Quiet Render Engine

**Proposal ID**: #25  
**Change Request ID**: `CR-2026-036`  
**Bundle ID**: `CRP-2026-007-LCM_Inventory-v7.1.0-Single-Instance-Dashboard-Tab-Coordination`  
**Origin Repository**: `LCM_Inventory`  
**Author**: rgbig  
**Status**: Pushed (Accepted)  
**Date**: 2026-08-30  

---

## 1. Problem Statement
During rapid review, debugging, and command iterations, repeated invocations of `Show-CmControlHub.ps1` caused browsers to open multiple duplicate Control Hub tabs (up to ~10 tabs), causing desktop clutter and resource overhead.

---

## 2. Proposed Architecture & Remediation
1. **Single-Instance BroadcastChannel Coordination**:
   * Implement `BroadcastChannel('LCM_CM_CONTROL_HUB_CHANNEL')` in `CM_CONTROL_HUB.html`.
   * Newly focused/loaded dashboard tabs claim the active instance, causing peer dashboard tabs to close themselves or render a minimal deactivation placeholder.
2. **Preservation of Documentation & Tool Sub-Tabs**:
   * Ensure `openInNewBrowserTab` documentation viewers are exempt from the channel broadcast and remain permanently open.
3. **Quiet Background Rendering**:
   * Add `-NoLaunch` parameter to `Show-CmControlHub.ps1` so background scripts update the cached data quietly without launching browser tabs.

---

## 3. Verification Plan
* Validate automated tab retirement on new instance launch.
* Validate `-NoLaunch` flag in `Show-CmControlHub.ps1`.
* Run readiness test suite `Test-WorkspaceReadiness.ps1`.
