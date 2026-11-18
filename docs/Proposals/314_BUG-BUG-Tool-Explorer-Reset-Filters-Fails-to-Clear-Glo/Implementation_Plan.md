# Implementation Plan: BUG-314 - Tool Explorer & Show-ToolIntents Reset Filters Fix & Pipe (OR) Filter Support

## 1. Executive Summary & Problem Context
1. In `assets/lcm-tool-explorer.js`, `resetFilters()` fails to reset module-scoped `searchFilter` and fails to strip URL search parameters via `window.history.replaceState()`, leading to persistent query string recreation on refresh.
2. In `assets/lcm-tool-explorer.js` and `tools/Show-ToolIntents.ps1`, search filtering treats pipe characters `|` as literal text rather than OR alternatives, causing queries like `bcr|macrium|ahk` to fail.
3. In `tool_catalog.json`, no tool description references AHK, causing `ahk` queries to return 0 matches.

## 2. Gate 0 Traceability
- **Clause 1**: Implement pipe `|` disjunction support in `matchRowSearch()` and `matchQuery()` in `assets/lcm-tool-explorer.js`.
- **Clause 2**: Implement pipe `|` disjunction support in `Show-ToolIntents.ps1`.
- **Clause 3**: Update `resetFilters()` in `assets/lcm-tool-explorer.js` to reset `searchFilter = ''` and call `window.history.replaceState()`.
- **Clause 4**: Update `Invoke-MacriumDailyBcrBaseline.ps1` synopsis/description with AHK/AutoHotkey references and regenerate `tool_catalog.json`.

## 3. Proposed Changes
### Component 1: `assets/lcm-tool-explorer.js`
- Enhance `matchRowSearch()`:
  - Split tokens by whitespace (AND).
  - Split each token by `|` (OR alternatives).
  - Match if any alternative matches (or none if negated with `!`).
- Enhance `matchQuery()`:
  - Split by `|` to allow OR in column text filters.
- Enhance `resetFilters()`:
  - Set `searchFilter = ''`.
  - Strip query params: `if (window.history && window.history.replaceState) window.history.replaceState({}, document.title, window.location.pathname)`.

### Component 2: `tools/Show-ToolIntents.ps1`
- Enhance `renderTable()`:
  - Support pipe `|` splitting in `globalQuery`.

### Component 3: `Invoke-MacriumDailyBcrBaseline.ps1` & `config/tool_catalog.json`
- Update script description with AutoHotkey / AHK automation details.
- Run `Update-ToolCatalog.ps1` to re-index the catalog.

## 4. Verification Plan
- Unit verification of pipe `|` alternation in `matchRowSearch()`.
- Live browser test: filter `bcr|macrium|ahk` displays all matching tools.
- Live browser test: `↺ Reset Filters` clears URL search string and survives refresh.
- Run `Test-GeneralReadiness.ps1 -Repo LCM_Inventory` (6/6 gates).
