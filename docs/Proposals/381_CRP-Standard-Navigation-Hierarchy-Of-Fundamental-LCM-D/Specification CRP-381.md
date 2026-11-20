# Specification: CRP-381

Module: docs/Proposals/381_CRP-Standard-Navigation-Hierarchy-Of-Fundamental-LCM-D/Specification CRP-381.md  
Purpose: Standard Navigation Hierarchy Of Fundamental LCM Displays  
Path: LCM_Inventory/docs/Proposals/381_CRP-Standard-Navigation-Hierarchy-Of-Fundamental-LCM-D/Specification CRP-381.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 15:58:54

```yaml
CRP-ID: CRP-381
Title: Standard Navigation Hierarchy Of Fundamental LCM Displays
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 15:58:54
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator (live test 2026-11-20): "we must define a standard hierarchy of the fundamental tools of LCM (not the other
tools)." Found because the Inventory Explorer offers no way back to the Tools Explorer, unlike other displays, which
show "Back" or sometimes "Close" (BUG-380 B10).

## 2. Gate 0 Contract (draft, for operator acceptance)

### Target State

T1 A documented hierarchy of the fundamental LCM displays (e.g. Tools Explorer as entry point; Control Hub, Inventory
Explorer, Rules, Tool Intents and the other standard displays below it), defined by the operator.

T2 Uniform navigation in every fundamental display: one control back to its parent in the hierarchy, with one name
and one place (Back vs. Close decided once).

T3 Browser history and the browser Back button follow the navigation (operator 2026-11-20: "the history of my browse
never shows the items LCM displayed"). Verified 2026-11-20: Firefox and Zen history hold the display pages
themselves (`/hub`, `/tools`, `/inventory`, ... with titles), but not the items opened inside them: selecting a
CRP, document or tool changes the page content in script without changing the URL (`/hub?Id=` is recorded with an
empty Id). Target: every item view has its own URL (`history.pushState`, e.g. `/hub?Id=CRP-381`,
`/inventory?repo=LCM_AI&doc=README.md`) and its own page title naming the item; opening such a URL directly shows
that item (deep link); Back returns to the previous view.

T4 LCM displays open in the Windows default browser (`cmd /c start`); LCM neither chooses, overrides nor checks the
browser (operator Gate 2 review 2026-11-20, item 3: the operator prefers Zen for LCM work and sets it as the Windows
default; this switch is not LCM's task to doubt or correct). No browser path or browser choice in LCM code.

### Invariants and Exit Criteria

- Only the fundamental LCM displays; other tools are out of scope.
- Exit: operator live test walks the hierarchy up and down from every fundamental display; the browser history lists
  the items visited, and reopening one from the history shows that item.

### Explicit Non-Goals

- Restyling the displays (BUG-380 covers the visual defects).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Open Operator Questions

- Which displays count as fundamental, and which one is the root?
- One control name: ANSWERED (operator Gate 2 review 2026-11-20, item 4): the top control is "Back" (to the parent
  display); closing is done with the browser's own controls and never performs a back operation.

## Operator Remarks From The Live Test (2026-11-20, Inventory Explorer Docs)

> the contrast is such that the entire top section is unreadable in dark mode, and the switch to get into light
> mode is missing. The area should be frozen, which it may be, but when the height of the display is reduced, it
> just moves out of view entirely. The close button has become superfluous and must go (the back button works).
> Size of the text output is still short. Remedy: move the line "0 of 5 selected" to the frozen section. Make
> sure the document list is scrollable if there are more items, splitting available space between the list and
> the view areas.

Mapping: contrast and theme switch = B2, B5, B7; frozen area = B3; preview height = B8 (rows below). New: remove
the Close button of the document window; "n of m selected" moves into the frozen section; the document list
scrolls and shares the height with the view area.

## Absorbed From BUG-380 (operator 2026-11-20, Q1 A: cohort with this CRP)

Original rows quoted unchanged; they are closed with this CRP (RULE-LCM-031).

| # | Found | What the operator saw | Cause (verified) | Requirement |
|:---|:---|:---|:---|:---|
| B2 | Inventory Viewer in dark mode (live test 2026-11-20) | text in the top third barely readable | contrast of the dark theme too low (not yet analysed) | Displays must be readable in both themes (DisplayStandardsPolicy) |
| B3 | Inventory Explorer (live test 2026-11-20) | the header part is not frozen; it scrolls away | not analysed | header and filters stay visible while the table scrolls (DisplayStandardsPolicy) |
| B4 | Inventory Explorer | the boxes (cards/fields) are far too big | not analysed | compact layout as in the other standard displays |
| B5 | Inventory Explorer and standard displays in general | the dark/light mode switch is missing; it has not been showing in the standard displays for some time | not analysed | every standard display offers the theme switch |
| B6 | Inventory Explorer table | the column headings are not selection drop-downs (no column filters) | not analysed | column headings work as filter drop-downs like in the other tables |
| B7 | Inventory Explorer | contrast is low in some parts and not uniform (extends B2) | not analysed | uniform, readable contrast in both themes |
| B8 | Inventory Explorer, Docs of LCM_AI | the document preview shows only about 10 lines, the space below stays mostly empty; one more line "0 of 4 selected" | not analysed | the preview uses the available height |
| B10 | Inventory Explorer (live test 2026-11-20) | no button back to the Tools Explorer ("Back", in other displays sometimes "Close"), unlike the other displays | not analysed | uniform navigation to the parent display; the hierarchy itself is defined by CRP-381 |
