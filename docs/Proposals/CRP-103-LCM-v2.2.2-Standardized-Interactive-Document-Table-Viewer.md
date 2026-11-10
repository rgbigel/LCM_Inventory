---
Proposal-ID: CRP-103
CR-ID: CR-2026-054
Scope: LCM Platform (.lcm) & Shared Dashboards
Version: 10.2.0
Affected-Repos: [LCM_Inventory, LCM_AI, HaSSD06_Inventory, .lcm]
Status: OPEN (Bundled in BUNDLE-STD-DISPLAY-10.0.0)
Date: 2026-10-13
Author: Rolf, LCM_AI Engine
Priority: High
Target Scope: Universal Dashboard UI/UX Standard & Interactive Table Engine
Affected Version Range: 10.0.0 -> 10.0.0
Impacted Repositories: [LCM_Inventory, LCM_AI, HaSSD06_Inventory, .lcm]
Logical-Bundle: BUNDLE-STD-DISPLAY-10.0.0
---

# CRP-103: Universal LCM Table UI/UX Standard & Interactive Table Display Specification

## 1. Executive Summary & Intent
Codify and enforce the definitive **Universal LCM Table UI/UX Design Standard** across all interactive web applications, dashboards, and modal viewers in the LCM workspace (LCM Tool Explorer, Workspace Inventory Explorer, CM Control Hub, Home Assistant Subsystem Inventory Viewer).

This proposal aggregates all proven, high-utility interaction patterns across our existing viewers into a single authoritative UX specification: Windows-style top-right `[⬅ Back]` navigation, persistent overflow scrollbars, row selection checkboxes, per-row operational action buttons, left-adjusted global search with `!term` negation, column-aligned dropdown filters, metric summary filter cards, high-contrast theme toggling, and universal `[❓ Help / Guide]` dialogs.

---

## 2. Definitive Universal Table UI/UX Specification

Every table view across the LCM ecosystem will mandate the following unified architecture:

### 2.1 Navigation & Header Structure (Windows-Style Back Navigation)
* **Top-Right `[⬅ Back]` Button**:
  * Positioned in the upper right header toolbar (matching classic Windows navigation).
  * Deterministically returns the operator to the calling view/dashboard without relying on browser history or risking application exit.
* **Universal Header Actions Bar**:
  * `[☀️/🌙 Light/Dark Mode Switch]`: High-contrast theme toggle with cross-dashboard `localStorage` state persistence.
  * `[🔄 Refresh Data & View]`: Live re-read from disk/API (governed under universal F5 keyboard listener per `CRP-115`).
  * `[🖨️ Print / PDF]`: Global formatted document print preview *(Print engine mechanics governed under `CRP-128`)*.
  * `[❓ Help / Guide]`: Comprehensive modal dialog explaining all columns, status badges, shortcut keys, and icon legends.

### 2.2 Table Layout, Row Selection & Operational Actions
1. **Row Selection Checkboxes & Batch Processing**:
   * Master `Select All` checkbox in the table header.
   * Per-row checkbox for individual selection.
   * Batch action bar active when $\ge 1$ item selected (Batch Print/PDF, Batch Export, Batch Accept, Batch Edit).
2. **Standardized Per-Row Action Buttons**:
   * `[🔍 Show / Inspect]`: Opens detailed modal view with full metadata, content, and parameters.
   * `[🖨️ Print / Save PDF]`: Formatted single-record or multi-record PDF/Print preview *(Governed under `CRP-128`)*.
   * `[✏️ Edit]`: Dispatches external editor (e.g. Notepad++) *(Governed under `CRP-129`)*.
   * `[⚡ Run / Execute]` *(where applicable)*: Dispatches real process execution via `lcm://` protocol on active desktop.

### 2.3 Search, Column-Aligned Filters & Metric Cards
* **Top Metric Summary Cards**: Interactive cards displaying real-time counts that act as instant 1-click filter toggles.
* **Top-Line Search Field**: Left-adjusted global search box supporting `!term` negation filtering (e.g. `!hass`, `!python`).
* **Column-Aligned Dropdown Selectors**: Dedicated dropdown filter controls positioned directly above their respective columns (excluding free long text).
* **Multi-Column Sorting**: Bidirectional sorting toggles (`⇅`) on all column headers.

### 2.4 Viewport Adaptation & Overflow Scrollbar Management
* **Visible, Styled Scrollbars**: Whenever table data or modal content exceeds container bounds, custom-styled, high-contrast scrollbars (`scrollbar-gutter: stable`, `overflow-y: auto`, `overflow-x: auto`) must automatically appear.
* **No Content Clipping**: Information must never be truncated or hidden offscreen without explicit scrollbar affordance.
* **Frozen Sticky Table Headers**: The head of the table displays must be frozen, i.e., excluded from scrolling (`position: sticky; top: 0; z-index: 50/51`), ensuring column headers, sort toggles, and filter controls remain continuously pinned and visible while scrolling rows vertically.

---

## 3. Application Matrix Across Dashboards

| Dashboard Application | Target File / Runner | Universal Table Standard Capabilities |
|:---|:---|:---|
| **1. LCM Tool Explorer** | `Tools_Explorer_LCM.html` / `Show-Tools.ps1` | Multi-select checkboxes, batch run/export, Show/Print/Edit row actions, Top-Right `[⬅ Back]`, universal Help/Guide, overflow scrollbars. |
| **2. CM Control Hub** | `CM_CONTROL_HUB.html` / `Show-CmControlHub.ps1` | Standard table row actions, Active CM Log modal, Historical Archive viewer, Top-Right `[⬅ Back]` to Inventory button. |
| **3. Workspace Inventory Explorer** | `WORKSPACE_INVENTORY_VIEWER.html` / `Show-WorkspaceInventoryApp.ps1` | Universal row actions (Show, Print, Onboard, Un-Git), Light/Dark theme atom, Top-Right `[⬅ Back]`, Help dialog. |
| **4. HA Subsystem Viewer** | `SHOW_HA_INVENTORY.html` / `Show-HaInventory.ps1` | Entity/Device selection checkboxes, batch state inspect, Print/PDF, Light/Dark theme atom, Top-Right `[⬅ Back]`. |

---

## 4. Extracted Proposals (Processed Separately)

> [!NOTE]
> Per operator bundling directive for `BUNDLE-STD-DISPLAY-10.0.0`:
>
> 1. **Document Table Viewer Implementation (Original Section 3, Item 1)**:
>    - **Extracted to**: [`CRP-130`](file:///D:/Git_Repositories/LCM_Inventory/docs/Proposals/CRP-130-LCM_Inventory-10.0.0-Document-Table-Viewer-Implementation.md) (*Workspace Inventory Document Table Viewer Implementation*).
>    - **Rationale**: The specific modal table redesign of `WORKSPACE_INVENTORY_VIEWER.html` (`Docs` tab) represents repository inventory feature work, whereas `CRP-103` in `BUNDLE-STD-DISPLAY-10.0.0` establishes the foundational interactive table display engine.
>
> 2. **Multi-Page Print & PDF Engine**:
>    - **Extracted to**: [`CRP-128`](file:///D:/Git_Repositories/LCM_Inventory/docs/Proposals/CRP-128-LCM-10.0.0-Universal-Multi-Page-Table-Print-And-PDF-Export-Engine.md).
>
> 3. **Desktop Editor Dispatch & Governance Advisory**:
>    - **Extracted to**: [`CRP-129`](file:///D:/Git_Repositories/LCM_Inventory/docs/Proposals/CRP-129-LCM-10.0.0-Standard-Desktop-Editor-Dispatch-And-Governance-Advisory-Hook.md).


