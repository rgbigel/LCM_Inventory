# Change Request Proposal: Universal Table Standard Display Enhancements

- **Proposal ID**: `CRP-108`
- **Target Repository**: `LCM` (`Git_Repositories/.lcm/assets`, `Workspace_Inventory`)
- **Target Version**: `v7.5.0`
- **Domain**: `Lifecycle Model (LCM) Universal UI/UX & Table Display Standard`
- **Author**: Rolf, Workspace_AI Governance
- **Status**: `OPEN` (Bundled in `BUNDLE-STD-DISPLAY-v7.5.0` - Awaiting Operator PROCEED)
- **Created**: `2026-09-07 12:35:00`
- **Priority**: `HIGH`
- **Target Scope**: `.lcm/assets/lcm-dashboard-theme.css`, `.lcm/assets/lcm-table-engine.js`, `.lcm/tools/internal/Show-Tools.ps1`, `.lcm/tools/internal/Show-Rules.ps1`, `CM_CONTROL_HUB.html`
- **Affected Version Range**: `v7.0.0 - v7.5.0`
- **Impacted Repositories**: `Git_Repositories`, `Workspace_Inventory`
- **Logical Bundle**: `BUNDLE-STD-DISPLAY-v7.5.0` (Standard Display Interactive Repairs)

---

## 1. Objective & Operational Rationale

This Change Request Proposal codifies and incorporates universal display and filtering standards across all Lifecycle Model (LCM) interactive table displays (including Tool Explorer, Rules Explorer, CM Control Hub, and Inventory Viewers).

### Deficits in Existing Table Implementations
1. **Filter Fragmentation**: Some dashboards (e.g. earlier revisions of `Show-Rules.ps1`) utilized horizontal pill/button rows for domain filtering, consuming vertical space and lacking table alignment. Column-header dropdowns aligned directly with table columns provide superior spatial organization and density.
2. **Missing Standard Control Actions**: Universal control buttons (Dark/Light mode toggle `🌓`, Reset All Filters `↺`) were inconsistently present across different tool dashboards.
3. **Transient Feedback Deficits**: Command actions (such as copying rules or exporting catalogs) previously relied on short-lived toasts that vanished before operators could read the full destination paths.

---

## 2. Normative Display Standards

### 2.1 Column-Header Dropdown Filtering Standard
- Horizontal button/pill rows for column attributes are prohibited.
- All table headers `MUST` include a secondary aligned `<tr class="col-filter-row">` containing `<select class="col-filter-select">` elements for each filterable dimension (e.g. Rules, Identifiers, Domain, Scope, Subsystem, Role, Audience, Admin).
- **Exemption**: Long text or free-form description columns `MUST NOT` render dropdown selectors.
- Distinct option values `MUST` be dynamically populated and update in harmony with search terms.

### 2.2 Standard Toolbar Control Suite
Every LCM table dashboard `MUST` provide standard toolbar controls:
1. **Search Input**: Full-text search with `!negation` token support.
2. **Display Mode Toggle (`🌓 Dark/Light`)**: Persisting theme preference across sessions.
3. **Reset All Filters (`↺ Reset`)**: Instant restoration of all dropdowns and search inputs to baseline.

### 2.3 Persistent 2-Line Action Results Banner
- Dashboards executing export, copy, or dispatch commands `MUST` render an Action Results display area located directly beneath the search toolbar.
- Output `MUST` present structured multi-line feedback (minimum 2 lines) indicating:
  - **Line 1**: Primary action outcome with full filesystem path (e.g. `D:\Git_Repositories\Workspace_AI\docs\LCM_Rules_Gemini_Export.md`).
  - **Line 2**: Secondary synchronization outcome, matrix update, or governance directive (e.g. `D:\Git_Repositories\Workspace_AI\docs\LCM-Rules-Cross-Reference.md`).
- Results banner `MUST` remain visible until dismissed or superseded by another action.

---

## 3. Extracted Proposals (Processed Separately)

> [!NOTE]
> Per operator bundling directive for `BUNDLE-STD-DISPLAY-v7.5.0`, non-table-display sections originally present in CRP-108 have been extracted into dedicated follow-up proposals:
>
> 1. **Section 2.4 (Multi-Page Print & PDF Engine Compliance)**:
>    - **Extracted to**: [`CRP-128`](file:///D:/Git_Repositories/Workspace_Inventory/docs/Proposals/CRP-128-LCM-v7.5.0-Universal-Multi-Page-Table-Print-And-PDF-Export-Engine.md) (*Universal Multi-Page Table Print and PDF Export Engine*).
>    - **Rationale**: Separates document print stylesheets and PDF rendering mechanics from interactive DOM table navigation.
>
> 2. **Section 2.5 (Standardized Editor Dispatch & Governance Hook)**:
>    - **Extracted to**: [`CRP-129`](file:///D:/Git_Repositories/Workspace_Inventory/docs/Proposals/CRP-129-LCM-v7.5.0-Standard-Desktop-Editor-Dispatch-And-Governance-Advisory-Hook.md) (*Standard Desktop Editor Dispatch and Governance Advisory Hook*).
>    - **Rationale**: Separates desktop daemon process dispatch (`notepad++.exe`) and governance modal hooks from table layout and filtering.

