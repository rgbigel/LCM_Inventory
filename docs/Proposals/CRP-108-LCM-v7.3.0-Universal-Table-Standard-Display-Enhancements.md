# Change Request Proposal: Universal Table Standard Display Enhancements

- **Proposal ID**: `CRP-108`
- **Target Repository**: `LCM` (`Git_Repositories/.lcm/assets`, `Workspace_Inventory`)
- **Target Version**: `v7.3.0`
- **Domain**: `Lifecycle Model (LCM) Universal UI/UX & Table Display Standard`
- **Author**: Rolf, Workspace_AI Governance
- **Status**: `OPEN` (Awaiting Operator Review & PROCEED Trigger)
- **Created**: `2026-09-07 12:35:00`
- **Priority**: `HIGH`
- **Target Scope**: `.lcm/assets/lcm-dashboard-theme.css`, `.lcm/assets/lcm-table-engine.js`, `.lcm/assets/lcm-table-print-atom.js`, `.lcm/tools/internal/Show-Tools.ps1`, `.lcm/tools/internal/Show-Rules.ps1`, `CM_CONTROL_HUB.html`
- **Affected Version Range**: `v7.0.0 - v7.3.0`
- **Impacted Repositories**: `Git_Repositories`, `Workspace_Inventory`

---

## 1. Objective & Operational Rationale

This Change Request Proposal codifies and incorporates universal display, filtering, and printing standards across all Lifecycle Model (LCM) interactive table displays (including Tool Explorer, Rules Explorer, CM Control Hub, and Inventory Viewers).

### Deficits in Existing Table Implementations
1. **Filter Fragmentation**: Some dashboards (e.g. earlier revisions of `Show-Rules.ps1`) utilized horizontal pill/button rows for domain filtering, consuming vertical space and lacking table alignment. Column-header dropdowns aligned directly with table columns provide superior spatial organization and density.
2. **Missing Standard Control Actions**: Universal control buttons (Dark/Light mode toggle `🌓`, Reset All Filters `↺`, and Print/Preview Atom `🖨️`) were inconsistently present across different tool dashboards.
3. **Transient Feedback Deficits**: Command actions (such as copying rules or exporting catalogs) previously relied on short-lived toasts that vanished before operators could read the full destination paths, or omitted the exact target file locations.
4. **Single-Page Print Clipping**: In several dashboards, container CSS styles (`height: 100vh; overflow: hidden;` or scrollable viewports) caused browser print and PDF generation to clip output to a single page (displaying only the first few items) instead of paginating the entire list across multiple pages.
5. **Editor Dispatch Failures & Governance Gaps**: Clicking "Edit" frequently failed to dispatch to Notepad++ due to daemon payload mismatches, falling back to silent clipboard copying, and lacked immediate governance reminders regarding CRP requirements for modified assets.

---

## 2. Normative Display Standards

### 2.1 Column-Header Dropdown Filtering Standard
- Horizontal button/pill rows for column attributes are prohibited.
- All table headers `MUST` include a secondary aligned `<tr class="col-filter-row">` containing `<select class="col-filter-select">` elements for each filterable dimension (e.g. Rules, Identifiers, Domain, Scope, Subsystem, Role, Audience, Admin).
- Distinct option values `MUST` be dynamically populated and update in harmony with search terms.

### 2.2 Standard Toolbar Control Suite
Every LCM table dashboard `MUST` provide standard toolbar controls:
1. **Search Input**: Full-text search with `!negation` token support.
2. **Display Mode Toggle (`🌓 Dark/Light`)**: Persisting theme preference across sessions.
3. **Reset All Filters (`↺ Reset`)**: Instant restoration of all dropdowns and search inputs to baseline.
4. **Print / PDF Preview (`🖨️ Print / Preview`)**: Direct invocation of `LcmTablePrintAtom`.

### 2.3 Persistent 2-Line Action Results Banner
- Dashboards executing export, copy, or dispatch commands `MUST` render an Action Results display area located directly beneath the search toolbar.
- Output `MUST` present structured multi-line feedback (minimum 2 lines) indicating:
  - **Line 1**: Primary action outcome with full filesystem path (e.g. `D:\Git_Repositories\Workspace_AI\docs\LCM_Rules_Gemini_Export.md`).
  - **Line 2**: Secondary synchronization outcome, matrix update, or governance directive (e.g. `D:\Git_Repositories\Workspace_AI\docs\LCM-Rules-Cross-Reference.md`).
- Results banner `MUST` remain visible until dismissed or superseded by another action.

### 2.4 Multi-Page Print & PDF Engine Compliance
- All table containers `MUST` declare print-specific CSS rules resetting viewport constraints:
  ```css
  @media print {
    html, body, .table-container, .table-viewport {
      height: auto !important;
      overflow: visible !important;
    }
    table { width: 100% !important; border-collapse: collapse !important; }
    thead { display: table-header-group !important; }
    tr { page-break-inside: avoid !important; }
  }
  ```
- This guarantees that document generation paginates 100% of rows across multiple pages without truncation.

### 2.5 Standardized Editor Dispatch & Governance Hook
- Editing source assets `MUST` dispatch directly to Notepad++ (`notepad++ "<path>"`) or configured default editor via the Session 1 desktop daemon.
- When an authoritative rule or governed tool is opened for editing, the system `MUST` display an immediate governance advisory:
  `⚠️ Note: Changes to authoritative governance rules require a formal Change Request Proposal (CRP) per RULE-LCM-012.`

