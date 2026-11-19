# Specification: CRP-382

Module: docs/Proposals/382_CRP-Live-Data-For-Standard-Displays-From-SQLite-Views/Specification CRP-382.md  
Purpose: Live Data For Standard Displays From SQLite Views  
Path: LCM_Inventory/docs/Proposals/382_CRP-Live-Data-For-Standard-Displays-From-SQLite-Views/Specification CRP-382.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 00:30:23

```yaml
CRP-ID: CRP-382
Title: Live Data For Standard Displays From SQLite Views
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 00:30:23
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator (live test 2026-11-20): "the display rendering on data change should not even require rendering at all, just a
refresh"; the expected capability is a fast "show view" from SQLite. Found through BUG-380 B11 (ShowTools times out
because every open re-renders the display for about 7 s).

Verified state (2026-11-20): the display renderers read the JSON stores (`Show-LcmControl.ps1` proposals.json,
`Show-ToolIntents.ps1` tool_intents.json, `Show-LCM_InventoryApp.ps1` inventory.json plus document files) and bake the
data into one HTML artifact per display (several MB each); since CRP-335 the daemon re-renders on every refresh request,
synchronously. The SQLite views (e.g. `v_user_tools`, `v_tool_intents_summary`) are used by no display.

## 2. Gate 0 Contract (draft, for operator acceptance)

### Target State

T1 Standard display pages are static templates, rendered only when the template (format) changes.

T2 Each page fetches its data at load and on refresh from a daemon data route that answers from SQLite views
(proposals.db, tools.db); a refresh reloads data only.

T3 No display reads a JSON store (CRP-358).

### Invariants and Exit Criteria

- Same content and functions as today's displays (operator live test per display).
- Exit: opening and refreshing a display takes well under a second in the normal case; no re-render on data change.

### Explicit Non-Goals

- Visual redesign (BUG-380 B2-B10, CRP-381).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Open Operator Decision

How the Go daemon reads SQLite (it has no SQLite driver today):
- A: a pure-Go SQLite driver in the daemon (fastest; first external dependency);
- B: the daemon calls a small Python query helper per request (Python has SQLite built in; about 0.1-0.2 s per call);
- C: a resident Python data service next to the daemon.

## 4. Relation

CRP-358 (JSON stores retired; the displays are among their largest readers); CRP-335 (refresh semantics, superseded by
T2); BUG-380 B11 (symptom).
