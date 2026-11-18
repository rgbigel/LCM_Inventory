# Implementation Plan: CRP-171
# LCM Tool Explorer ShowTools Default Mode, Self-Tool Exclusion, and Dynamic Filtered Count Metric Card

| Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-171` |
| **State** | `SUGGESTED` (Gate 1 Planning Gate Halt) |
| **Target Repositories** | `LCM_Inventory`, `.lcm` (Root) |
| **Target Files** | `LCM_Inventory/modules/LcmToolCatalog.psm1`, `LCM_Inventory/assets/lcm-tool-explorer.js`, `LCM_Inventory/assets/lcm-tool-explorer.js` |
| **Author** | Rolf, Antigravity AI Assistant |
| **Date** | 2026-10-13 |

---

## 1. Proposed Code Changes

### Step 1: `LCM_Inventory/modules/LcmToolCatalog.psm1`
- Locate `#card-noexit` in `<div class="metrics-grid">`.
- Replace `#card-noexit` with an inactive metric card:
  ```html
  <div class="metric-card" id="card-filtered-count" onclick="void(0)" style="cursor: default;" title="Number of items currently displayed after applying active filters">
      <div class="metric-label">Items Showing</div>
      <div class="metric-value" id="metric-filtered-value">$($metrics.Total)</div>
      <div class="metric-sub">Filtered Result</div>
  </div>
  ```

### Step 2: `lcm-tool-explorer.js` (both `LCM_Inventory/assets` and `LCM_Inventory/assets`)
- **Default ShowTools Filter on Original Call**:
  - In `initApplication()`, check if `sessionStorage.getItem('lcm_tools_showfilter')` or initial startup is active.
  - If no explicit CLI search/filter override is present (`!searchFilter && currentTool === 'All'`), activate `toggleShowFilter()` / set `isFilteringShowTools = true`, and apply the visual active state to `#btn-show-tools-filter`.
- **Self-Tool Exclusion**:
  - In `applyFilters()`, when evaluating `matchShowFilter`, exclude items where:
    ```javascript
    const isSelfTool = (t.ShortName && t.ShortName.toLowerCase() === 'showtools') ||
                       (t.Name && (t.Name.toLowerCase() === 'show-tools.ps1' || t.Name.toLowerCase() === 'showtools.cmd'));
    ```
    If `isFilteringShowTools` is `true`, return `false` if `isSelfTool` is true.
- **Dynamic Filtered Count Metric Card**:
  - In `applyFilters()`, add:
    ```javascript
    const filteredCountEl = document.getElementById('metric-filtered-value');
    if (filteredCountEl) {
        filteredCountEl.innerText = filtered.length;
    }
    ```
  - In `filterByCard(cardType)`, remove the `noexit` branch.

---

## 2. Verification & Testing Strategy

1. **Gate 1 Halt Verification**:
   - Verify proposal is recorded in `proposals.json` in `suggested` state.
   - Stop and await operator direction (`Proceed` or `do 171`).

2. **Upon Gate 1 Authorization (`Proceed` / `do 171`)**:
   - Apply edits to `LCM_Inventory/modules/LcmToolCatalog.psm1`, `LCM_Inventory/assets/lcm-tool-explorer.js`, and `LCM_Inventory/assets/lcm-tool-explorer.js`.
   - Regenerate the tool catalog and HTML viewer via `ShowTools -NoLaunch` or `Update-ToolCatalog.ps1`.
   - Validate that:
     1. Opening `ShowTools` loads with the "ShowTools" filter mode active by default.
     2. The table does not include a line for `ShowTools` while in ShowTools filtering mode.
     3. The "NoExit Locked" button is replaced by the inactive "Items Showing" card, dynamically displaying the count of filtered items.
     4. Toggling filters or searching updates the "Items Showing" value in real time.
   - Run readiness test: `pwsh LCM_Inventory/tools/Test-RepoReadiness.ps1`.
   - Present Beyond Compare diff / review for Gate 2 review disposition.
