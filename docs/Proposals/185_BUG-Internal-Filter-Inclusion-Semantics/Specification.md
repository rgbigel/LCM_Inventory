---
id: BUG-185
title: Tool Explorer Internal Button Filter Inversion and Empty Catalog Defect
type: BUG
status: VERIFICATION
created_at: 2026-10-13 17:45:00
author: Rolf, Antigravity AI Assistant
origin_repo: LCM_Inventory
target_baseline: 10.0.0
affected_repos:
  - LCM_Inventory
  - .lcm
scope: Tool Explorer Filtering Engine & Audience Segregation
severity: High
root_cause: |
  In lcm-tool-explorer.js, the 'Int.' toolbar toggle was erroneously implemented as an exclusive filter
  (matchAud = t.Audience === 'internal') rather than an inclusion gate. Because no tools in the catalog
  had Audience === 'internal' and all User/Developer tools were rejected, activating 'Int.' produced 0 visible tools.
---

# BUG-185: Tool Explorer Internal Button Filter Inversion and Empty Catalog Defect

## 1. Problem Statement & Root Cause

### 1.1 Observed Defect
When clicking the `🔒 Int.` toolbar button in Tool Explorer (`SHOW_TOOLS.html`), even with all search queries and column selectors reset, the data table displayed zero tools (an entirely blank table).

### 1.2 Root Cause Analysis
In `lcm-tool-explorer.js`, the filtering logic for `isFilteringInternal` was written as:
```javascript
if (isFilteringInternal) {
    matchAud = (t.Audience && t.Audience.toLowerCase() === 'internal');
} else { ... }
```
This caused two critical failures:
1. **Exclusive Filter Inversion**: Instead of lifting the default suppression of internal tools, activating `Int.` instructed the filter engine to show *only* tools whose `Audience` property was strictly equal to `"internal"`.
2. **Total Catalog Blockade**: All tools with `Audience === 'User'` or `Audience === 'Developer'` were filtered out. Since the tool catalog uses `User` and `Developer` as its primary audience taxonomy, zero tools satisfied the predicate, yielding an empty view.

---

## 2. Remediated Specification

1. **Inclusion Semantics**:
   - `Int.` is an **inclusion toggle** (analogous to "Show Hidden Items").
   - When `Int.` is **OFF** (default): Any tool classified as `"Intern*"` (matching `Audience`, `Category`, `Role`, `Group`, or `Domain` starting with `intern`) is suppressed, unless explicitly requested in a column filter.
   - When `Int.` is **ON**: The suppression rule is lifted. Internal tools are displayed alongside all other tools matching the active audience and column criteria.
2. **Preservation of Regular Tools**:
   - Toggling `Int.` ON never hides normal User or Developer tools.
3. **Reset Behavior**:
   - When all filters are reset and `Int.` is ON, the full catalog (User, Developer, and Internal) is visible.

---

## 3. Appended Defects & Ergonomic Hardening (BUG-185 Append)

### 3.1 Persistent Horizontal Scrollbar
- **Defect**: On wide or high-resolution displays (e.g. 4K 4096x2160), the table stretched across the entire viewport without scroll capability.
- **Remediation**: Hardened `.table-container` with `overflow-x: scroll !important; width: 100%;` and table with `min-width: 1900px !important;`. Direct CSS embedded in `<style id="lcm-tool-catalog-style">` and `<style id="standard-table-display-style">` to prevent caching and CORS issues.

### 3.2 Dynamic Total / Selected Tools Counter
- **Requirement**: Display active visible tools versus total catalog count directly on `#card-all` formatted as `201 / 99` with label `Total / Selected Tools`.
- **Remediation**: Card initialized with compile-time total and dynamically updated on every filter change in `applyFilters()`.

### 3.3 Toolbar Icon Sizing & Presets Label Casing
- **Requirement**: Increase toolbar icons (`🖨️`, `📊`, `🔒`, `⚡`, `↺`, `💾`, `🔄`, `🗑️`, `💬`, `📁`) to 16px font-size. Prevent uppercase transformation of `Presets:`.
- **Remediation**: Added inline flex styling and 16px icons across all toolbar action buttons; applied `text-transform: none !important;` to `#filter-presets-select` label.

### 3.4 Dynamic Column Width Adjustment & Naming
- **Requirement**: Rename header `ToolName` to `Tool Name`. Rename button `Int.` to `Intern`. Prevent excessive stretching of `Tool Name` in Source Files (Dev) mode. Dropdowns auto-widen to fit option text.
- **Remediation**: Implemented `autoAdjustColumnWidths()` measuring character lengths and applying both `width`, `minWidth`, and `maxWidth` constraints so extra horizontal viewport space is absorbed by `Description` rather than stretching tool names.

### 3.5 Audience Lockup & Missing Tools 1-8 Neutralization
- **Defect**: Startup state had `isShowToolsButtonOn = true`, `Group = 'LCM'`, and `Audience = 'User'`, hiding tools 1 through 8 (which belong to `HaSSD06` with Developer audiences or non-Show verbs).
- **Remediation**: Cleaned startup and reset logic so all dropdowns default to `'All'`, `isShowToolsButtonOn = false`, and selecting `'All'` cleanly displays all catalog tools.

### 3.6 Off-By-One Resolution (201 Tools Parity)
- **Defect**: Browser client filtered out self-tool stems (`selfStems = ['show-toolsexplorer', ...]`), leaving 200 items in `toolsData` while catalog index went up to 201 (`201 Workspace Push`), causing an off-by-one gap and mismatched counter.
- **Remediation**: Removed artificial `selfStems` exclusion from `lcm-tool-explorer.js`. All 201 catalog tools are loaded with 1:1 parity (`201 / 201`), matching the final `201 Workspace Push` entry.

### 3.7 Full Viewport Frozen Header Architecture (Zero Scrollbar Off-Screen)
- **Defect**: The main page body had vertical overflow, causing the entire top section (Header, Metrics, Search, Presets) to scroll off-screen and pushing the bottom horizontal scrollbar out of view when positioned at the top.
- **Remediation**: Converted the application frame to a full-viewport flex column:
  - `html, body { height: 100vh; overflow: hidden !important; }`
  - `.container { height: 100vh; display: flex; flex-direction: column; overflow: hidden; padding: 8px 12px; }`
  - `header, .metrics-grid, .filter-panel-top { flex: 0 0 auto; margin-bottom: 8px; }`
  - `.table-container { flex: 1 1 auto; min-height: 0; overflow-y: auto !important; overflow-x: auto !important; }`
  This freezes everything from "LCM Tool Explorer" through "Total / Selected..." and the column filter row (`# All Tools`) permanently at the top. Only table body rows scroll vertically, and the horizontal scrollbar is permanently pinned within the viewport.

### 3.8 Live Resize Auto-Shrinking Without Refresh
- **Defect**: Table was locked to a rigid `min-width: 1900px !important;` and lacked live resize listeners, requiring a manual page refresh to adapt column widths when narrowing the window.
- **Remediation**: Set responsive `min-width: 1280px; width: 100%;` on table. Attached live debounced `window.addEventListener('resize')` listener to `autoAdjustColumnWidths()` to automatically scale and shrink column widths in real-time as the user resizes the window.
