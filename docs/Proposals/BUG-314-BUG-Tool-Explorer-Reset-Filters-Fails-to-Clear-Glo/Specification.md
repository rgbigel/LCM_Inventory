# Change Request Proposal: BUG-314

```yaml
CRP-ID: BUG-314
Title: [BUG] Tool Explorer & Show-ToolIntents Reset Filters Fix & Pipe (OR) Filter Support
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-10 15:33:00
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
1. **Reset Filters Query-String State Purge**:
   In LCM Tool Explorer (`assets/lcm-tool-explorer.js`), clicking `↺ Reset Filters` clears `sessionStorage` but does not clear the module-scoped `searchFilter` or strip URL query parameters via `window.history.replaceState()`. Consequently, transient test parameters (such as `?Filter=a%26b`) persist in the browser address bar and are re-applied upon refresh.
2. **Disjunctive (OR) Pipe Filtering (`|`)**:
   Neither Tool Explorer nor Show-ToolIntents supports disjunctive alternation (OR). Queries like `bcr|macrium|ahk` fail with 0 matches because the engines evaluate the entire string literally. The search engines must split tokens containing `|` into alternatives and match rows matching any alternative.
3. **AHK Catalog Searchability**:
   `Invoke-MacriumDailyBcrBaseline.ps1` relies on AutoHotkey (AHK) for dialog automation, but its catalog metadata does not mention AHK/AutoHotkey, causing searches for `ahk` to return 0 results.

## 2. Gate 0 Contract
### Target State
1. **Tool Explorer & Show-ToolIntents Filter Engine**:
   - Supports pipe `|` disjunctions (OR) in global search and column filters (e.g. `bcr|macrium|ahk`, `env:ps1|env:cmd`).
   - Space separation preserves conjunction (AND).
   - Negation prefix `!` preserves exclusion (`!dev|test`).
2. **Reset Filters Execution**:
   - `resetFilters()` blanks `#search-input.value = ''` and sets `searchFilter = ''`.
   - Cleans the browser address bar query string via `window.history.replaceState({}, document.title, window.location.pathname)`.
   - Restores the unfiltered tools list immediately and maintains clean state upon browser refresh (F5).
3. **Catalog Discoverability**:
   - `Invoke-MacriumDailyBcrBaseline.ps1` synopsis and catalog metadata explicitly index `AutoHotkey` / `AHK`, allowing searches for `ahk` to match.

### Invariants and Exit Criteria
- `bcr|macrium|ahk` returns tools matching `bcr`, `macrium`, or `ahk`.
- Query strings are purged from the browser URL upon clicking `↺ Reset Filters`.
- All quality gates in `Test-GeneralReadiness.ps1` pass 6/6 with 0 syntax errors.

### Explicit Non-Goals
- Cause no havoc; do not break existing `!negation` or `col:val` search functionality.

## 3. Technical Requirements & Invariants
- Invariant 1: Pipe `|` operator parsed in `matchRowSearch()` and `matchQuery()` in `assets/lcm-tool-explorer.js`.
- Invariant 2: Pipe `|` operator parsed in `Show-ToolIntents.ps1` global query filter.
- Invariant 3: `history.replaceState` in `resetFilters()` without page reload.
- Invariant 4: `Update-ToolCatalog.ps1` synchronizes updated AHK descriptions.
