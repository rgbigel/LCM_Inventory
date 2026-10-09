# CRP-182 Implementation Plan: Tool Explorer Ergonomics, Bulk Taxonomy & App Grouping

## 1. Technical Components & Affected Files
* [d:\Git_Repositories\LCM_Inventory\assets\lcm-tool-explorer.js](file:///d:/Git_Repositories/LCM_Inventory/assets/lcm-tool-explorer.js) — Core UI rendering, filtering, alias management modal, bulk column assignment, and dynamic sequence numbering.
* [d:\Git_Repositories\LCM_Inventory\tools\Show-ToolsExplorer.ps1](file:///d:/Git_Repositories/LCM_Inventory/tools/Show-ToolsExplorer.ps1) — HTML compilation, version metadata injection (`v8.0.0`), and baseline catalog binding.
* [d:\Git_Repositories\LCM_Inventory\docs\README.md](file:///d:/Git_Repositories/LCM_Inventory/docs/README.md) — Documentation update for Tool Explorer features.
* [d:\Git_Repositories\LCM_Inventory\data\proposals\proposals.json](file:///d:/Git_Repositories/LCM_Inventory/data/proposals/proposals.json) — Ledger registration.

---

## 2. Granular Implementation Steps

### Phase 1: Version Baseline & Header Branding (Items 5 & 6)
1. **Version Parity**:
   - In `Show-ToolsExplorer.ps1`, update `$scriptVersion = "8.0.0"` and dynamic header extraction from `Requirements.md`.
   - In `lcm-tool-explorer.js`, ensure all references to `v7.5.0` are updated to `v8.0.0`.
2. **Column Header Rebranding (`Subsys` $\rightarrow$ `Group`)**:
   - In `Show-ToolsExplorer.ps1` and `lcm-tool-explorer.js`, change the column header text from `Subsys` to `Group`.
   - Update column filters and sort labels to reflect `Group`.
   - Maintain backward compatibility with existing overrides (`Subsystem`, `Group`, `Domain`).

### Phase 2: Toolbar Buttons & Initial Filter State (Items 1 & 2)
3. **`Int.` Audience Button**:
   - Add an `Int.` toggle button immediately to the right of `ShowTools` in the toolbar.
   - Tied to `sessionStorage.getItem('lcm_tools_filter_internal')`.
   - When active, includes tools where `Audience === 'Internal'` or `'Admin'`. When inactive (default), internal tools are hidden.
4. **`ShowTools` Default Active State**:
   - Check `sessionStorage.getItem('lcm_tools_initialized')`.
   - If not set (first open of window):
     - Set `showtools_active = true`.
     - Apply pristine filter: `Audience = 'User'`, `Group = 'LCM'`, clear all other filters, sort by `ShortName` ascending.
     - Mark `lcm_tools_initialized = true`.
   - On page refresh (`lcm_tools_initialized === true`), preserve the user's current filter and toggle state without resetting.

### Phase 3: Dynamic Sequence Numbering & Column Sizing (Items 7 & 8)
5. **Sequence Numbering (`#`)**:
   - In `renderTable()` of `lcm-tool-explorer.js`, compute row numbers dynamically as `idx + 1` from the filtered, sorted display array rather than using catalog array index `tool.Index`.
6. **ShortName Column Sizing & Stacked Aliases**:
   - Constrain width of `ToolName` column in ShortName view (e.g. `max-width: 240px; word-break: break-all`).
   - Format aliases into vertical stacked pills/lines:
     ```html
     <div class="alias-stack"><span class="alias-pill">alias1</span><span class="alias-pill">alias2</span></div>
     ```

### Phase 4: Alias Management & Generalized Bulk Taxonomy (Items 3 & 4)
7. **Granular Alias Management Modal**:
   - In the Rename / Edit modal, replace the bulk "Clear All Aliases" button with:
     - Interactive tag list of current aliases, each with a red `×` remove button.
     - An "Add Alias" input box with an "Add" button.
     - Saves changes directly to the tool's override record.
8. **Generalized Bulk Column Rename / Assignment**:
   - Add a "Bulk Assign" button in column filter dropdowns (or header menu) for `Group` and `Category`.
   - When clicked, opens a modal:
     - Displays: *"Bulk Assign [Column Name] for X currently visible/filtered tools"*.
     - Input field or dropdown with existing values + custom entry.
     - Applies new value to all currently filtered items in `storedOverrides`, persists to disk via daemon sync, and refreshes the view.

### Phase 5: Verification & Documentation (Item 9)
9. **Recompile & Validate**:
   - Run `Show-ToolsExplorer.ps1 -NoLaunch` to regenerate `SHOW_TOOLS.html`.
   - Verify all 9 items in the browser.
   - Update in-app `Help` modal in Tool Explorer and workspace READMEs.
