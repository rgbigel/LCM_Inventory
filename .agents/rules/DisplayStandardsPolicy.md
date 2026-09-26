---
name: DisplayStandardsPolicy
description: Authoritative governance policy for LCM HTML Displays, Interactive Table Dashboards, CSS Tokens, Sticky Filter Headers, Theme Synchronization, and Desktop Dispatching.
globs: "*"
---
# File: DisplayStandardsPolicy.md

Module: DisplayStandardsPolicy  
Purpose: Governs presentation standards, CSS design system tokens, sticky double-row header layouts, theme persistence, and interactive desktop dispatching across all LCM-generated HTML viewers and dashboards.  
Path: .agents/rules/DisplayStandardsPolicy.md  
Authors: Rolf, Workspace_AI Governance  
Version: 8.5.1
Status: Authoritative Policy
Date: 2026-09-26

---

## 1. Scope & Motivation

Multiple LCM tools, subsystem viewers, inventory explorers, and diagnostic scripts generate interactive HTML dashboards and reports (e.g., `Show-Tools.ps1`, `Show-Rules.ps1`, `Show-Subsystems.ps1`, `Show-HaInventoryApp.ps1`, `Show-CmdFolderAnalysis.ps1`).

To ensure a cohesive, professional, accessible, and high-performance user experience across all repositories and tools, all LCM-generated HTML presentations `MUST` adhere to these authoritative Display Standards.

---

## 2. Authoritative Rules

### RULE-DSP-001: Canonical CSS Design System Tokens
1. All generated HTML viewers `MUST` import or embed the canonical `StandardTableDisplay.css` design system.
2. Direct hardcoded styling colors (e.g. `color: #111`, `background: white`) `SHALL NOT` be used in tables or containers; all elements `MUST` reference CSS variables:
   - Surface Tokens: `--bg-primary`, `--bg-secondary`, `--bg-card`, `--bg-header`, `--border-color`.
   - Typography Tokens: `--text-primary`, `--text-secondary`, `--text-muted`, `--font-sans` (`Inter`), `--font-mono` (`JetBrains Mono`).
   - Accent & Status Tokens: `--accent`, `--accent-hover`, `--success`, `--danger`, `--warning`, `--info`.
3. Fixed-width text (code snippets, file paths, IDs, parameters) `MUST` use `--font-mono` and wrap in `<span class="tag">` or `<code>`.

### RULE-DSP-002: Universal Dark/Light Theme Persistence
1. All interactive viewers `MUST` support dynamic Dark and Light theme modes.
2. The active theme `MUST` synchronize with `localStorage.getItem('lcm_theme')` so that theme preferences persist seamlessly across all tools and tabs.
3. Theme switching `SHALL` be instantaneous and toggled via standard UI buttons (`☀️ Light` / `🌙 Dark`) in the top navigation header.

### RULE-DSP-003: Standard View Header & Breadcrumb Navigation
1. The top header of every viewer `MUST` include:
   - The primary Title and a Version badge (e.g. `v5.4.0`).
   - Live relative and absolute timestamp of generation (`Updated: YYYY-MM-DD HH:MM:SS`).
   - Breadcrumb navigation / Back link (`[⬅️ Back to Hub]` or `[⬅️ Back]`).
   - Theme toggle button and Print/Export action button.

### RULE-DSP-004: Double-Row Sticky Table Headers
1. Data tables `MUST` implement a sticky header layout (`position: sticky; top: 0; z-index: 10;`) so table headers remain visible during vertical scrolling.
2. Tables `MUST` implement a two-row header structure:
   - **Row 1 (`<th>`)**: Column titles with click-to-sort controls and clear sort indicators.
   - **Row 2 (`.col-filter-row`)**: Column-aligned filter dropdown selectors and text search inputs, allowing granular multi-column filtering.

### RULE-DSP-005: Large, Legible Action & Sort Indicators
1. Action icons (Inspect `🔍`, Copy `📋`, Run `▶️`, Help `❓`) `MUST` be rendered with minimum font size of 14–15px and distinct hover animations.
2. Column sort indicators `MUST` use clear directional glyphs (`▲` ascending, `▼` descending, `⇅` unsorted) with legible contrast.

### RULE-DSP-006: Column-Qualified Negation Search Engine & Live Match Counters
1. Primary filter inputs `MUST` support tokenized search including column-qualified expressions (`Column:value`, `Column:!value`, `!Column:value`) and general negation tokens (`!exclude`).
2. All standard table dashboards `MUST` leverage `LcmTableEngine.filterTable()` / `LcmTableEngine.bindSearch()` or implement equivalent column-qualified negation matching.
3. Every filtered view `MUST` display a live, dynamic counter showing match progress (e.g., `Showing 42 of 150 items`).

### RULE-DSP-007: Print & PDF Export Integration
1. High-density data tables and audit reports `MUST` integrate `lcm-table-print-atom.js` or standard print stylesheets (`@media print`) ensuring zero header cutoff and clean pagination across multi-page PDF exports.

### RULE-DSP-008: Interactive Desktop Dispatch Routing
1. Any CLI script or utility that builds and displays an HTML viewer `MUST` invoke `Invoke-InteractiveDesktop.ps1` per `RULE-PS-011` to ensure reliable browser launching on interactive session 1.

