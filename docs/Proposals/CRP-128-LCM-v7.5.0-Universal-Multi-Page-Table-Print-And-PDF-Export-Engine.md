# Change Request Proposal: CRP-128
# Universal Multi-Page Table Print and PDF Export Engine

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-128` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Review & PROCEED Trigger) |
| **Origin Repository** | `LCM` / Assets & UI Engines (`.lcm/assets`, `LCM_Inventory`) |
| **Target Scope** | `.lcm/assets/lcm-table-print-atom.js`, `.lcm/assets/lcm-dashboard-theme.css`, `CM_CONTROL_HUB.html`, `SHOW_TOOLS.html` |
| **Author** | Rolf, LCM_AI Governance |
| **Date** | 2026-09-09 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Extracted From** | Extracted from `CRP-108` (Section 2.4) and `CRP-103` (Section 2.1 Print/PDF Action) to separate printing engine architecture from interactive table display bundling (`BUNDLE-STD-DISPLAY-v7.5.0`). |

---

## 1. Executive Summary & Intent
Extract and formalize the dedicated multi-page printing and PDF rendering engine across all Lifecycle Model (LCM) table displays.
In earlier web dashboard iterations, container CSS styles (`height: 100vh; overflow: hidden;` or scrollable viewports) caused browser print and PDF generation to clip output to a single visible page, omitting subsequent rows.

This proposal implements print-specific CSS viewport resets, page-break management, and the `LcmTablePrintAtom` print dialog engine to ensure complete, multi-page pagination across all table dashboards without truncation.

---

## 2. Normative Specification

### 2.1 Print-Specific CSS Viewport Reset
All LCM table containers `MUST` declare print-specific CSS media rules:
```css
@media print {
  html, body, .table-container, .table-viewport, .main-content {
    height: auto !important;
    max-height: none !important;
    overflow: visible !important;
  }
  table { 
    width: 100% !important; 
    border-collapse: collapse !important; 
  }
  thead { 
    display: table-header-group !important; 
  }
  tr { 
    page-break-inside: avoid !important; 
  }
  .toolbar, .search-box, .col-filter-row, .action-buttons, .theme-toggle {
    display: none !important;
  }
}
```

### 2.2 Shared Print Engine Atom (`lcm-table-print-atom.js`)
- Standardizes formatted print preview triggering from the global toolbar `[🖨️ Print / Preview]`.
- Strips active filter UI elements and unrolls paginated/scrollable virtual lists before invoking `window.print()`.

---

## 3. Affected Components
- `.lcm/assets/lcm-dashboard-theme.css`
- `.lcm/assets/lcm-table-print-atom.js`
- `LCM_Inventory/docs/CM_CONTROL_HUB.html`
- `.lcm/tools/internal/SHOW_TOOLS.html`
- `.lcm/tools/internal/Show-Rules.ps1`
