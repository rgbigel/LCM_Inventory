# Change Request Proposal: CRP-138
# Tool Explorer ShowTools Button, Header Layout, and Horizontal Scrolling Refinements

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-138` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Activation per RULE-LCM-015) |
| **Origin Repository** | `LCM / Git_Repositories` |
| **Target Scope** | `.lcm/modules/LcmToolCatalog.psm1`, `.lcm/assets/lcm-tool-explorer.js`, `.lcm/assets/lcm-dashboard-theme.css` |
| **Author** | Operator Directive / CRP Intake |
| **Date** | 2026-09-11 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Governing Policy** | `ProposalReviewFlowPolicy.md` (`RULE-LCM-012`, `RULE-LCM-015`, `RULE-LCM-016`) |
| **Originating Proposals** | [`BUG-133`](file:///D:/Git_Repositories/Workspace_Inventory/docs/Proposals/BUG-133-LCM-v7.5.0-Tool-Explorer-UI-Regressions-Help-And-Parameter-Fixes.md) and `BUNDLE-STD-DISPLAY-v7.5.0` (`CRP-025`, `CRP-108`) |

---

## 1. Executive Summary & Intent

During operator testing of the Tool Explorer (`ShowTools`), several UI/UX refinements were identified:
1. **ShowTools Button Behavior & Naming**:
   - The button `Show-* Tools` does not behave identically to the `📊 Show-* Tools` preset in the dropdown (it toggled styling but was not evaluated in `applyFilters()`).
   - The button should be renamed to **`ShowTools`** and achieve exact behavioral parity with the preset.
2. **Top Header Layout (Theme Toggle Placement)**:
   - The Light Mode toggle (`#btn-theme-toggle`) is currently grouped in the secondary toolbar row.
   - It should be moved up into the primary top header `<div class="header-actions">`, positioned directly in front of the `🔄 Refresh` button.
3. **Table Horizontal Scrolling & Column Clipping**:
   - On screens or window widths where the `NoExit` column is pushed beyond the visible viewport boundary, no horizontal scrollbar is provided, causing the column to appear vanished.
   - Ensure the table container enforces explicit horizontal scrolling (`overflow-x: auto`) with styled scrollbars.

---

## 2. Proposed Implementation Scope

1. **`LcmToolCatalog.psm1`**:
   - Relocate `#btn-theme-toggle` into `<div class="header-actions">` immediately before `<button class="btn-refresh">`.
   - Update the toolbar button label from `📊 Show-* Tools` to `📊 ShowTools`.
   - Add `overflow-x: auto` to `.table-container`.
2. **`lcm-tool-explorer.js`**:
   - Update `toggleShowFilter()` / `isFilteringShowTools` so that `applyFilters()` actually filters the tool rows to those matching `Show-` / `Show*`, matching the preset filter logic.
3. **`lcm-dashboard-theme.css`**:
   - Ensure `.table-container` scrollbar styling is visible across light and dark modes.
