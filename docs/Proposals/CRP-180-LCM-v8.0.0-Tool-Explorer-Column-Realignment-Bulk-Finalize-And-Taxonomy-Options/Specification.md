# Change Request Proposal: CRP-180

```yaml
CRP-ID: CRP-180
Title: Tool Explorer Ergonomics: Column Realignment, Bulk Finalize, and Precompiled Dynamic Taxonomy Options
Scope: .lcm, LCM_Inventory, Tool Explorer UI, Tool Catalog Sync Engine, LCM Desktop Daemon
Baseline-Version: v8.0.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
Impacted-Repositories:
  - Git_Repositories
  - LCM_Inventory
```

---

## 1. Problem Statement & Objectives

Operators navigating and editing tools in the LCM Tool Explorer required ergonomic enhancements to streamline day-to-day workflow and resolve display and interaction friction:

1. **Suboptimal Column Ordering & Header Verbosity**:
   - The original column ordering (`#` / `Tool Name` / `Env.` / `Subsystem` / `Role` / `Audience` / `Admin` / `Category` / `Description` / `Action & Modes` / `NoExit`) separated tool identity from action triggers and descriptive metadata.
   - Long header labels consumed excessive horizontal table real estate.
   - **Target**:
     `#` / `ToolName` / `Actions & Modes` / `Subsys` / `Role` / `Description` / `Category` / `Audience` / `Env.` / `Admin` / `NoExit`.

2. **Actions Column Button Ergonomics & Bulk Finalization**:
   - Blocked rows required concise, unambiguous visual indicators: the red "no entry" sign (`⛔`) alone without redundant text labels.
   - Row-level buttons required distinct chromatic hierarchy: `Reset` in bright warning red (`#f85149`) and `Set` (Finalize) in action green (`#3fb950`).
   - Finalizing dozens of staged modifications individually was tedious; operators required a bulk `SetAll` button in the header filter row alongside `↺ Reset` to finalize all blocked tools across the entire catalog simultaneously.

3. **Precompiled Taxonomy Dropdowns & Dynamic `+ New...` Extension**:
   - Dropdown filters and in-cell editors previously offered hardcoded or arbitrary strings.
   - Taxonomies must be strictly derived from values actually present in the catalog (`Subsystems`, `Roles`, `Categories`), precompiled during HTML generation and persisted to `.lcm/config/tool_explorer_options.json`.
   - Operators can dynamically add a new taxonomy entry using `+ New...`, which prompts for the new value, synchronously registers it with the daemon (`POST /add_explorer_option`), persists it to `tool_explorer_options.json`, and updates active selects without requiring runtime recalculation or manual file edits.
   - Pruning occurs automatically upon subsequent catalog compilation if a taxonomy value is no longer referenced.
   - Columns `#`, `ToolName`, `Env.`, `Admin`, and `NoExit` do not offer `+ New...`.

4. **Horizontal Scrollbar Visibility Guarantee**:
   - On widescreen high-resolution monitors (>1600px width), `overflow-x: auto` caused browsers to hide the horizontal scrollbar track completely when the table fit within the viewport.
   - The table requires guaranteed, persistent horizontal scrollability (`overflow-x: scroll !important`) and an expanded `min-width: 1800px !important;` with a styled 12px accent scrollbar thumb.

---

## 2. Technical Modifications

### 2.1 Table Header & Filter Row Realignment (`LcmToolCatalog.psm1`)
- Reordered all `<th>` headers and filter row `<td>` elements to the canonical 11-column order:
  1. `#` (`th-idx`)
  2. `ToolName` (`th-name`)
  3. `Actions & Modes` (`th-actions`)
  4. `Subsys` (`th-subsys`)
  5. `Role` (`th-role`)
  6. `Description` (`th-desc`)
  7. `Category` (`th-cat`)
  8. `Audience` (`th-audience`)
  9. `Env.` (`th-env`)
  10. `Admin` (`th-admin`)
  11. `NoExit` (`th-noexit`)
- Added `SetAll` button and `↺ Reset` button to the `Actions & Modes` column filter cell.
- Injected precompiled `<option>` elements into `Subsys`, `Role`, and `Category` filter dropdowns, concluding with `<option value="__NEW__">+ New...</option>`.
- Injected `window.__LCM_OPTIONS__ = $optionsJson;` into the HTML payload.

### 2.2 Precompiled Taxonomy Extraction & Persistence (`LcmToolCatalog.psm1`)
- Extracted unique non-empty, trimmed values for `Subsystems`, `Roles`, and `Categories` across all catalog items during compilation.
- Merged existing entries from `.lcm/config/tool_explorer_options.json` with active items, pruning obsolete ones upon compilation.
- Atomic write to `.lcm/config/tool_explorer_options.json`.

### 2.3 Daemon API Dynamic Taxonomy Addition (`LcmDesktopDaemon.ps1`, `DaemonActionController.ps1`)
- Added endpoint `POST /add_explorer_option` accepting JSON `{ "type": "Subsystems"|"Roles"|"Categories", "value": "..." }`.
- Implemented `DaemonActionController.AddExplorerOption` to validate, append, sort, and atomically persist the updated options JSON file.

### 2.4 Table Rendering, Blocked Status, and Cell Editing (`lcm-tool-explorer.js`)
- Realigned `renderTable` row generation to produce cells matching the 11-column order.
- Replaced blocked status pill text with standalone `⛔` icon.
- Styled `Reset` button with `#f85149` (red) and `Set` button with `#3fb950` (green).
- Added `finalizeAllBlocked()` function accessible via the `SetAll` header button.
- Re-architected `openCellEditor` for `Subsys`, `Role`, and `Category` to populate from `window.__LCM_OPTIONS__` with `+ New...` support.
- Added `handleSelectFilterChange()` and `handleCellEditSelectChange()` to prompt and invoke daemon `/add_explorer_option`.
- Mirrored all JS changes from `LCM_Inventory/assets/lcm-tool-explorer.js` to `.lcm/assets/lcm-tool-explorer.js`.

### 2.5 Horizontal Scrollbar Hardening (`LCMToolCatalog.css`)
- Added `overflow-x: scroll !important;` to `.table-container` to force browsers to always render the scrollbar track.
- Increased table `min-width` from `1560px` to `1800px !important`.
- Configured 12px high-contrast scrollbar thumb (`#388bfd` / `#79c0ff` hover) across WebKit and Firefox engines.
- Mirrored stylesheet from `LCM_Inventory/assets/LCMToolCatalog.css` to `.lcm/assets/LCMToolCatalog.css`.
