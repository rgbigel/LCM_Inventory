# Specification: CRP-390

Module: docs/Proposals/390_CRP-UX-Uniformity-Of-Standard-Displays/Specification CRP-390.md  
Purpose: UX Uniformity Of Standard Displays  
Path: LCM_Inventory/docs/Proposals/390_CRP-UX-Uniformity-Of-Standard-Displays/Specification CRP-390.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Suggested  
Date: 2026-11-20 21:59:44

```yaml
CRP-ID: CRP-390
Title: UX Uniformity Of Standard Displays
Scope: LCM_Inventory
Baseline-Version: 10.8.4
Author: Rolf, Claude
Date: 2026-11-20 21:59:44
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 4
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-20: multiple instances of lacking UX uniformity in the standard displays; one common display contract (themes and contrast, frozen header, compact layout, theme switch, column filters, preview height, labels); takes over BUG-380 B2-B8 from CRP-381 (CRP-381 keeps navigation and B10).
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract (draft, for operator acceptance at the CDR)

### Instances Found (taken over from BUG-380, live tests 2026-11-20)

| ID | Display | Instance | Uniform target |
|:---|:---|:---|:---|
| B2 | Inventory Viewer, dark mode | text in the top third barely readable | readable in both themes |
| B3 | Inventory Explorer | header part not frozen, scrolls away | header and filters stay visible while the table scrolls |
| B4 | Inventory Explorer | boxes far too big | compact layout as in the other standard displays |
| B5 | Inventory Explorer and standard displays in general | dark/light switch missing | every standard display offers the theme switch |
| B6 | Inventory Explorer table | column headings are not filter drop-downs | column headings work as filter drop-downs everywhere |
| B7 | Inventory Explorer | contrast low in parts and not uniform | uniform, readable contrast in both themes |
| B8 | Inventory Explorer, Docs of LCM_AI | document preview uses about 10 lines of the available height | previews use the available height |

### Target State

T1 One written display contract for every standard display (DisplayStandardsPolicy as the rule source, made concrete
in the LCM_Inventory docs): theme tokens and contrast for light and dark, theme switch, frozen header with filters,
compact layout and spacing, table conventions (column filter drop-downs, sorting, counts), preview areas that use the
available height, and uniform names for common controls and labels.

T2 Every standard display follows the contract; the instances B2-B8 are gone and no new deviation is found in a
side-by-side check of all standard displays.

T3 A check that compares the displays against the contract (automated where the rendered page allows it, otherwise a
checklist in the live test), so new deviations are caught before the AR.

### Invariants and Exit Criteria

- Live test of every standard display in both themes, with the side-by-side check as a tickable list.
- No functional regression of the displays (existing display tests stay green).

### Explicit Non-Goals

- Navigation and display hierarchy, Back/Close, browser history (CRP-381, incl. BUG-380 B10).
- Live data from SQLite views and the data service (CRP-382).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

### Relation

- Taken over from CRP-381 on operator instruction 2026-11-20 22:00:29 (CRP-381 keeps its navigation goal).
- Coordinate with CRP-382: when it rebuilds the display pages as static templates, they follow this contract.

