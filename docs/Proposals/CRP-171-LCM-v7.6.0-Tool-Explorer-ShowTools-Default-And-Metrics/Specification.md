# Change Request Proposal: CRP-171

```yaml
CRP-ID: CRP-171
Title: LCM Tool Explorer ShowTools Default Mode, Self-Tool Exclusion, and Dynamic Filtered Count Metric Card
Scope: LCM Tool Explorer, Tools Catalog, UI Filtering & Metrics Cards
Baseline-Version: 10.2.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-10-13
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: Medium
Impacted-Repositories:
  - LCM_Inventory
  - .lcm
```

---

## 1. Executive Summary & Problem Context

During operator usage of the **LCM Tool Explorer** (`ShowTools`), three specific UI and operational behaviors were identified for optimization:

1. **Default "ShowTools" Display Filter Not Applied on Initial Launch**:
   - When the LCM Tool Explorer is originally launched (via `ShowTools`, `Show-Tools.ps1`, or desktop action), the default filter view does not apply the "ShowTools" filter mode (`isFilteringShowTools`).
   - Operator intent is that the initial dashboard presentation should default to standard displays (`Show-*` displays) active on startup.

2. **Self-Referential Tool Line in ShowTools Filtering Mode**:
   - In ShowTools filtering mode, the table displays a line for the command/tool `ShowTools` (`Show-Tools.ps1` / `ShowTools.cmd`).
   - Because the operator is already actively within the LCM Tool Explorer dashboard, displaying an item to launch `ShowTools` within the filtered view is redundant and causes clutter.

3. **Metrics Card Modernization: Drop "NoExit Locked" & Add Dynamic Filtered Item Counter**:
   - The top metrics card grid currently includes a clickable filter button for `NoExit Locked` (`#card-noexit`).
   - The operator directive is to drop the `NoExit Locked` card button, and replace it with an inactive status card/button displaying the live count of items currently showing after all active filters and searches are applied (`filtered.length`).

Additionally, as part of system reconnaissance, facts surrounding `Initialize-SharedAiMemory.ps1` were audited to establish whether cross-boot Drive `A:\.gemini` migration had been completed on the host system without making any unapproved modifications.

---

## 2. Technical Requirements & Architectural Invariants

### Invariant 1: Default Startup Filter Alignment
- On original dashboard initialization (`initApplication`), unless explicit CLI arguments override the search/filter parameters, the `ShowTools` filter mode (`isFilteringShowTools = true`) must be applied by default.
- The `📊 ShowTools` toolbar button (`#btn-show-tools-filter`) must visually reflect the active state (`active` class and accent styling).
- When the operator clicks `↺ Reset All Filters` or clicks the `📊 ShowTools` toggle button, the filter can be cleanly cleared back to all tools.

### Invariant 2: Exclusion of Self-Launch Tool in ShowTools Filtering Mode
- In `applyFilters()` within `lcm-tool-explorer.js`, when `isFilteringShowTools` is `true`, any item representing the explorer itself (`ShowTools`, `Show-Tools.ps1`, `ShowTools.cmd`, `ShowToolIndex`) must be excluded from the filtered results list.
- When `isFilteringShowTools` is disabled (all tools mode), `Show-Tools.ps1` remains visible and accessible in the full catalog.

### Invariant 3: Replacement of `NoExit Locked` Metric Card with Live Filtered Item Counter
- In `LcmToolCatalog.psm1`, remove `#card-noexit` (`NoExit Locked`).
- In its place, render an inactive metric card (`#card-filtered-count` with `style="cursor: default;"`):
  - Metric Label: `Items Showing`
  - Metric Value: `<span id="metric-filtered-value">$($metrics.Total)</span>`
  - Metric Sub: `After Filtering`
- In `lcm-tool-explorer.js`:
  - In `applyFilters()`, update `document.getElementById('metric-filtered-value').innerText = filtered.length;`.
  - In `filterByCard()`, remove the obsolete `noexit` branch.

### Invariant 4: Dual-File Asset Synchronization
- Both `LCM_Inventory/assets/lcm-tool-explorer.js` and `LCM_Inventory/assets/lcm-tool-explorer.js` must remain synchronized to guarantee identical behavior whether resolving from `LCM_Inventory` or `.lcm`.

---

## 3. Facts Concerning `Initialize-SharedAiMemory`

An audit was conducted on `Initialize-SharedAiMemory.ps1` and the active environment:
- **Junction Status**: `C:\Users\rgbig\.gemini` is a real NTFS directory (`LinkType` is empty), **not** an NTFS Directory Junction.
- **Drive A: Status**: Shared Drive `A:\.gemini` exists.
- **Historical Execution Log**: The script was executed once on 2026-10-13 (`Initialize-SharedAiMemory-20260830_110459.log`). While `robocopy` replicated 753 files to `A:\.gemini`, the directory rename step failed because the Antigravity IDE process held open file locks. As a result, the junction swap never completed.
- **Current Data Divergence**: `C:\Users\rgbig\.gemini` has received active writes up to the present date (2026-10-13), whereas `A:\.gemini` has remained frozen since 2026-10-13 and lacks newer directories (`antigravity-obsidian`, updated `bin`, and logs).
- **Recommendation**: In accordance with the prompt directive ("do not change anything yet"), zero modifications have been made to `Initialize-SharedAiMemory.ps1` or the filesystem.
