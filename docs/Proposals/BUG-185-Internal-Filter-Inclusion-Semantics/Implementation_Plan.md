# Implementation Plan: BUG-185 Tool Explorer Internal Button Filter Inversion and Empty Catalog Defect

## Target Files
1. `LCM_Inventory/assets/lcm-tool-explorer.js`
2. `.lcm/assets/lcm-tool-explorer.js`
3. `LCM_Inventory/assets/LCMToolCatalog.css`
4. `.lcm/assets/LCMToolCatalog.css`
5. `LCM_Inventory/assets/StandardTableDisplay.css`
6. `.lcm/assets/StandardTableDisplay.css`
7. `.lcm/modules/LcmToolCatalog.psm1`
8. `LCM_Inventory/data/proposals/proposals.json`

## Modifications

1. **Refactor Filtering Logic in `applyFilters()`**:
   - Introduce `matchesIntern()` helper checking `t.Audience`, `t.Category`, `t.Role`, `t.Group`, `t.Domain`.
   - Apply suppression when `!isFilteringInternal`.
   - Lift suppression when `isFilteringInternal` is true, keeping standard audience matching intact.

2. **Hardening Horizontal Scroll & CSS Injection**:
   - Embed CSS directly into `<style id="lcm-tool-catalog-style">` and `<style id="standard-table-display-style">` in `LcmToolCatalog.psm1`.
   - Set table `min-width: 1900px !important;` and `.table-container` `overflow-x: scroll !important; width: 100%;`.

3. **Dynamic Item Counter & Header Ergonomics**:
   - Update `#card-all` label to `Total / Selected Tools` and dynamically compute `toolsData.length + ' / ' + filtered.length` in `applyFilters()`.
   - Rename header `ToolName` to `Tool Name` and button `Int.` to `Intern`.
   - Increase toolbar button icons to 16px with inline flex alignment and enforce `text-transform: none !important;` on `Presets:`.

4. **Dynamic Column Width Adjustment (`autoAdjustColumnWidths`)**:
   - Calculate width based on mode and longest visible row item with `maxWidth` clamping.
   - Adjust dropdown column headers (`Group`, `Role`, `Category`, `Audience`) dynamically based on active selection length.

5. **Startup & Reset Normalization**:
   - Set `isShowToolsButtonOn = false` by default, clean session restore logic, and ensure `resetFilters()` resets all selectors to `All`.

6. **Synchronize Assets & Rebuild**:
   - Mirror updated assets across repositories.
   - Execute `Show-ToolsExplorer.ps1 -Audience All -NoLaunch` to regenerate `SHOW_TOOLS.html`.
