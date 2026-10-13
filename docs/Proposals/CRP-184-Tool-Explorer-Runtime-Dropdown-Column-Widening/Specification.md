---
id: CRP-184
title: Tool Explorer Runtime Dropdown Column Dynamic Auto-Widening
type: CRP
status: SUGGESTED
created_at: 2026-10-13 17:30:00
author: Rolf, Antigravity AI Assistant
origin_repo: LCM_Inventory
target_baseline: 10.0.0
affected_repos:
  - LCM_Inventory
  - .lcm
scope: Tool Explorer UI Ergonomics & Dynamic Table Column Resizing
---

# CRP-184: Tool Explorer Runtime Dropdown Column Dynamic Auto-Widening

## 1. Executive Summary & Feasibility Assessment

### 1.1 Problem Statement
In the LCM Tool Explorer (`SHOW_TOOLS.html`), columns `Group`, `Role`, and `Category` have been minimized in width so that only their header labels (`Group ⇅`, `Role ⇅`, `Category ⇅`) have room (~75px to 95px). However, when a user selects a value or expands the dropdown filter in one of these columns, option texts (such as `SystemConfiguration`, `QualityGate`, `DiagnosticTool`) exceed the column width.

While standard browser pop-up overlays expand automatically during interaction, the collapsed `<select>` element in the table header displays truncated or clipped text once a selection is committed.

### 1.2 Feasibility Analysis
- **Technical Feasibility**: **100% CAN-DO**.
- **Execution Mechanism**:
  1. **Canvas Measurement**: A lightweight hidden 2D canvas context (`ctx.measureText(text)`) measures exact pixel width of the active selection or options according to the computed font (`font: 600 12px Inter`).
  2. **Event Hooks**:
     - `onfocus`: Optionally expand the column to the maximum needed option width, or keep overlay native.
     - `onchange`: When a user selects a specific value, if `textWidth + 24px` exceeds the base header width (`minWidth`), expand the column `<th>` and corresponding `<col>` dynamically:
       `th.style.width = Math.min(maxAllowedWidth, measuredWidth + padding) + 'px';`
     - When reset or changed to `"All"`, smoothly snap back to the minimal header width (`80px`, `75px`, `95px`).
  3. **Visual Polish**: Add a subtle CSS transition (`transition: width 0.18s ease-in-out;`) to prevent jarring layout jumps.

---

## 2. Requirements & Specification

1. **Header Minimal Defaults**:
   - `Group`: Default width 80px (fits "Group ⇅").
   - `Role`: Default width 75px (fits "Role ⇅").
   - `Category`: Default width 95px (fits "Category ⇅").
2. **Runtime Expansion Condition**:
   - If selected option length requires more than column width, expand column to fit `selectedText + arrowPadding` (capped at max 180px).
   - If value is `"All"` (or empty), return column width to minimal header default.
3. **Zero Layout Breakage**:
   - `ToolName` and `Description` remain flexible with generous minimum widths (`320px` and `220px`).
   - Table container horizontal scrolling handles any total width expansion without clipping.
