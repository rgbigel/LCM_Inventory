# Change Request Proposal: CRP-115
# Universal F5 Keyboard Refresh and Refresh Button Removal Across Show-* Displays

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-115` |
| **Lifecycle State** | `OPEN` (Bundled in `BUNDLE-STD-DISPLAY-v7.5.0` - Awaiting Operator PROCEED) |
| **Origin Repository** | `LCM` / Desktop UI & Dashboards |
| **Target Scope** | Global `Show-*` Displays (`Show-Tools`, `Show-CmControlHub`, `Show-Rules`, `Show-CrpDates`, `Show-RepositoryInventory`, etc.) |
| **Author** | Rolf, LCM_AI |
| **Date** | 2026-09-07 |
| **Priority** | `High` |
| **Version Impact** | `v7.5.0` |
| **Logical Bundle** | `BUNDLE-STD-DISPLAY-v7.5.0` (Standard Display Interactive Repairs) |

---

## 1. Executive Summary & Problem Statement
Currently, several `Show-*` desktop and web dashboards lack a consistent, uniform method to refresh data:
1. Some views retain legacy on-screen **Refresh** buttons that clutter toolbar headers.
2. In other views, the refresh functionality was either omitted or is not bound to the standard desktop convention (`F5`).
3. Web-based single-page dashboards (such as `CM_CONTROL_HUB.html`, `SHOW_TOOLS.html`, `SHOW_RULES.html`, and dynamic viewer atoms) often intercept or allow native browser F5 reloads without preserving active filters, tabs, or scroll positions, or do not trigger the internal asynchronous API fetch / daemon re-query.

## 2. Proposed Architecture & Scope of Changes

### 2.1 Universal F5 Keyboard Listener
Every `Show-*` dashboard view will bind a global `keydown` event listener:
```javascript
window.addEventListener('keydown', (e) => {
  if (e.key === 'F5' || e.code === 'F5') {
    e.preventDefault();
    refreshDashboardData(); // Invokes internal dynamic data fetch & DOM refresh
  }
});
```
- Preserves user context (selected tab, search input query, active filter checkboxes/dropdowns, scroll position).
- Triggers dynamic asynchronous payload reload from local file or daemon endpoint (`/api/...`, `data.json`, `tool_catalog.json`, `proposals.json`).

### 2.2 Removal of On-Screen Refresh Buttons
- Search and eliminate all `<button id="btnRefresh"...>` and toolbar refresh icon/button elements from `CM_CONTROL_HUB.html`, `SHOW_TOOLS.html`, `Show-Rules.ps1`, `Show-CrpDates.ps1`, and related viewer generators.
- Clean up any unused CSS button styles or dangling click handlers associated solely with the removed buttons.

### 2.3 Visual Refresh Feedback
- When `F5` is pressed, display a subtle temporary status badge or progress spinner (e.g. "Refreshed at HH:mm:ss" or pulse animation) so the operator receives immediate visual confirmation of the data reload.

---

## 3. Affected Components
- `LCM_Inventory/docs/CM_CONTROL_HUB.html`
- `.lcm/tools/internal/LcmToolCatalog.psm1` & `SHOW_TOOLS.html`
- `.lcm/tools/internal/Show-Rules.ps1`
- `LCM_Inventory/tools/Show-CrpDates.ps1`
- `.lcm/assets/lcm-dashboard-theme.css` / theme components

---

## 4. Invariant Verification & Compliance
- **RULE-LCM-015 / 016**: Intake gate registered in `OPEN` state. No implementation changes occur prior to explicit `PROCEED 115`.
- **ASCII & Formatting Standards**: UTF-8 without BOM, standard line endings.

---

## 5. Next Steps
Awaiting operator review and explicit directive:
```text
PROCEED 115
```

