# Implementation Plan: CRP-184 Tool Explorer Runtime Dropdown Column Dynamic Auto-Widening

## Proposed Changes

### 1. `lcm-tool-explorer.js`
- Introduce a helper function `adjustColumnWidthForSelect(selectElement, minWidth, maxWidth)`.
- Use a reusable `<canvas>` context for zero-DOM-overhead text measurement.
- Bind `change` and `focus` events on `#group-select`, `#role-select`, and `#category-select`.
- On filter reset (`resetFilters()` and `resetColumnFilters()`), revert column widths to minimal defaults.

### 2. `LCMToolCatalog.css` & `StandardTableDisplay.css`
- Add CSS transition for table header width:
  `th.dynamic-col { transition: width 0.18s ease-in-out, min-width 0.18s ease-in-out; }`

### 3. Verification & Testing
- Load `SHOW_TOOLS.html`.
- Verify column widths default to minimum (only header label fits).
- Select long option (e.g. `SystemConfiguration`). Verify column smoothly widens to display the full option label.
- Click `↺ Reset`. Verify column returns to compact width.

## Proposed Status
- **Current State**: `SUGGESTED` (Gate 1 Planning Halt per `RULE-LCM-014`).
- **Proceed Trigger**: Awaiting operator directive (`Proceed` or `do`).
