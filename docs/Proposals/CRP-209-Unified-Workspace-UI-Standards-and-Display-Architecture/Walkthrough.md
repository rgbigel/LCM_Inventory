# CRP-209: Walkthrough - Unified Workspace UI Standards and Display Architecture

```yaml
CRP-ID: CRP-209
Status: Suggested
Author: rgbig
Date: 2026-10-02
```

## 1. Audit Receipts & Workspace UI Landscape

This walkthrough documents the initial discovery audit and baseline inventory of all UI assets, frameworks, and presentation engines detected across `D:\Git_Repositories\`:

### 1.1. Inspected UI File Inventory
* **HTML / Web Dashboards**:
  - `LCM_Inventory/assets/CM_CONTROL_HUB.html`
  - `LCM_Inventory/assets/WORKSPACE_INVENTORY_VIEWER.html`
  - `LCM_Inventory/assets/WORKSPACE_READINESS.html`
  - `LCM_Inventory/assets/LCM_SIDECAR.html`
  - `LCM_Inventory/assets/CM_CRP_DATES_READONLY.html`
  - `LCM_Supervision/assets/SUPERVISION_HUB.html`
  - `HaSSD06_Inventory/data/artifacts/SHOW_HA_INVENTORY.html`
  - `HaSSD06_Inventory/data/artifacts/Entities_Inventory_HaSSD06.html`
  - `.github/extensions/lcm-control-hub/control-hub.html`
* **CSS Design Systems**:
  - `.lcm/assets/StandardTableDisplay.css`
  - `.lcm/assets/LCMToolCatalog.css`
  - `.lcm/assets/lcm-dashboard-theme.css`
* **JavaScript Presentation & Table Engines**:
  - `.lcm/assets/lcm-table-engine.js` (Tokenized negation search & live counters)
  - `.lcm/assets/lcm-table-print-atom.js` (Multi-page PDF pagination)
  - `.lcm/assets/lcm-tool-explorer.js` (Interactive tool catalog, modals, taxonomy)
  - `.github/extensions/lcm-control-hub/control-hub-client.js` (REST client)
* **Native Desktop Windows GUIs**:
  - `HaSSD06/tools/subsystem/Show-HaAuthDialog.ps1` (WPF XAML Modal)
  - `LCM_Inventory/tools/Show-LcmActiveLauncher.ps1` (WPF Desktop Launcher)
  - `NextBootTray/NextBootTray.ps1` (WinForms NotifyIcon System Tray)
  - `BootEntryManager/Source/BootEntryManager.ps1` (WinForms OpenFileDialog)
* **Print-to-PDF / Paged Media**:
  - `RollingCalendar/Invoke-RollingCalendar.ps1` (`msedge --headless --print-to-pdf`)
* **Terminal UI Atoms**:
  - `LCM_Shared/modules/LcmProgressAtom.psm1` (ANSI progress bars & meters)

---

## 2. Key Observations & Implementation Receipts

1. **Phase 1 Complete (Governance Rule Expansion & Synchronization)**:
   - Expanded [`DisplayStandardsPolicy.md`](file:///d:/Git_Repositories/LCM_AI/.agents/rules/DisplayStandardsPolicy.md) to version 9.0.0 (`RULE-DSP-001` through `RULE-DSP-015`).
   - Integrated the architecture of [`CM_CONTROL_HUB_IMPLEMENTATION_0.html`](file:///d:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html) as the authoritative reference pattern.
   - Synchronized discovery matrix across [`AGENTS.md`](file:///d:/Git_Repositories/AGENTS.md) and [`LCM_AI/docs/LCM-Rules-Cross-Reference.md`](file:///d:/Git_Repositories/LCM_AI/docs/LCM-Rules-Cross-Reference.md).
2. **Next Steps**:
   - Align `CRP-196` Control Hub artifacts with these display standards.
   - Dispatch Beyond Compare visual review (`Invoke-BeyondCompareReview.ps1`).
