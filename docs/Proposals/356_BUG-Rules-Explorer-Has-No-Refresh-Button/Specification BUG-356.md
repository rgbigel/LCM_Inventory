# Specification: BUG-356

Module: docs/Proposals/356_BUG-Rules-Explorer-Has-No-Refresh-Button/Specification BUG-356.md  
Purpose: Rules Explorer Has No Refresh Button  
Path: LCM_Inventory/docs/Proposals/356_BUG-Rules-Explorer-Has-No-Refresh-Button/Specification BUG-356.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 21:38:57

```yaml
CRP-ID: BUG-356
Title: Rules Explorer Has No Refresh Button
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 21:38:57
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic A): Show-Rules.ps1 re-reads the rule files on every render, but only F5 triggers a re-render (POST /displays/refresh/rules); the page function refreshRules() has no button, RULE-DSP-003 requires a topbar refresh control. Fix: topbar refresh button calling the refresh, following the Control Hub btnRefresh pattern. Automatic re-render on rule-file changes is a separate CRP (after the JSON retirement).
- Merged finding (operator 2026-11-18): the status badge of every Standard Display covered page content (Tool Explorer: the execution output actions).
- Review: this Specification and the Walkthrough (screenshots taken by Claude). Plan: none beyond this Specification.

## 2. Gate 0 Contract
### Target State
- T1 The Rules Explorer toolbar has a "Refresh" button that re-renders the display (same as F5).
- T2 The status badge ("Current - <timestamp>") of every Standard Display sits inside the page header and covers no page content; a page without a header shows it fixed at the top right.
- T3 The badge time is the publication time of the displayed data; it changes only when the display is regenerated (operator Gate 2 finding 2026-11-18: it acted as a real-time clock).

### Invariants and Exit Criteria
- The badge keeps its function (state, revision tooltip); F5 unchanged.
- Exit: Rules Explorer shows the button; Tool Explorer bottom bar (Execution Output, Copy / Clear / Expand) is uncovered.

### Explicit Non-Goals
- Automatic re-render on rule-file changes (separate CRP after the JSON retirement).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
## Merged Findings

- [merged 2026-11-18 21:30:29] Operator 2026-11-18: the Standard Display status badge ("Current - <timestamp>", assets/lcm-display-freshness.js) is fixed at the bottom right and covers the Tool Explorer actions that show the execution output; place it at the top (inside the page header) so it hides nothing.

> About that badge. I thought it would only update when there was some change in the data displayed since it was generated. instead, it is a real-time clock that updates every few seconds. That timer is probably done by the daemon?? Anyway, not useful ( i do have a wristwatch)

(Operator, 2026-11-18, Gate 2; source of T3.)
