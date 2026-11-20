# Specification: CRP-382

Module: docs/Proposals/382_CRP-Live-Data-For-Standard-Displays-From-SQLite-Views/Specification CRP-382.md  
Purpose: Live Data For Standard Displays From SQLite Views  
Path: LCM_Inventory/docs/Proposals/382_CRP-Live-Data-For-Standard-Displays-From-SQLite-Views/Specification CRP-382.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 14:52:27

```yaml
CRP-ID: CRP-382
Title: Live Data For Standard Displays From SQLite Views
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 14:52:27
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

## 2. Gate 0 Contract (accepted by the operator 2026-11-20: "move to SQLite views")

### Target State

T1 Standard display pages are static templates, rendered only when the template (format) changes.

T2 Each page fetches its data at load and on refresh from a daemon data route that answers from SQLite views
(proposals.db, tools.db); a refresh reloads data only.

T3 No display reads a JSON store (CRP-358).

T4 Display state invariant (operator 2026-11-20, Q-B13 A; rule change via this CRP: ADMINMODE, RULE-AUTH-002):
a display never shows a lifecycle state that differs from the ledger; every display shows the time and source of
its data; after an action it refreshes only after the ledger write has completed (read-after-write), otherwise it
marks its data as stale. Until T4 is in force the ledger, not a display, is the authority for planning.

### Invariants and Exit Criteria

- Same content and functions as today's displays (operator live test per display).
- Exit: opening and refreshing a display takes well under a second in the normal case; no re-render on data change.

### Explicit Non-Goals

- Visual redesign (BUG-380 B2-B10, CRP-381).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Operator Decision (decided 2026-11-20: C)

How the Go daemon reads SQLite (it has no SQLite driver today). Operator 2026-11-20: "probably B or C, I need more
- A: a pure-Go SQLite driver in the daemon (fastest; first external dependency);
- B: the daemon calls a small Python query helper per request (Python has SQLite built in; about 0.1-0.2 s per call);
- C: a resident Python data service next to the daemon.

Decision (operator 2026-11-20): **C**, a resident Python data service. Basis: measured 2026-11-20 on tools.db (331 rows,
275 KB JSON): B about 75 ms per call (process start), the query itself about 4 ms. C brings its own lifecycle (start
and stop with the daemon, GoodMorning health check, restart after a crash), caller authentication for its listener
(D-36, not reachable from a web page) and non-elevated start; display pages and the daemon data route are the same
as with B.

## 4. Relation

CRP-358 (JSON stores retired; the displays are among their largest readers); CRP-335 (refresh semantics, superseded by
T2); BUG-380 B11 (symptom).

## Absorbed From BUG-380 (operator 2026-11-20, Q1 A: cohort with this CRP)

Original rows quoted unchanged; they are closed with this CRP (RULE-LCM-031). B13: its immediate defect (hub sync
actions ran asynchronously) was fixed in BUG-380 on 2026-11-20 (operator Q-B13 A); T2/T4 remove the cause class.

| # | Found | What the operator saw | Cause (verified) | Requirement |
|:---|:---|:---|:---|:---|
| B11 | `showtools` in the operator's terminal (live test 2026-11-20) | "Invoke-RestMethod: The request was canceled due to the configured HttpClient.Timeout of 5 seconds elapsing"; the Tool Explorer does not open | every open re-renders, unconditionally: `Open-LcmStandardDisplay` (`modules/LcmStandardDisplay.psm1`) always sends `POST /displays/refresh/<id>` and waits 5 s; the daemon (CRP-335) always runs `renderDisplay` and answers only after `Invoke-LcmDisplayRender.ps1` has finished (tools about 7 s, hub 2.7 s). The client's polling loop for state `Current` expects an immediate answer: client and daemon follow different designs. Root cause (operator 2026-11-20): data changes should need no rendering at all; addressed by CRP-382 (live data from SQLite views) | the ShowTools macro opens the Tool Explorer |
| B13 | Control Hub after "accept" of CRP-339 (operator 2026-11-20 13:35) | CRP-339 shown as "1 - Review / undecided" | the hub render of 13:35:55 (`data/artifacts/CM_CONTROL_HUB.html`) carries `state: suggested`, three seconds after the accept (13:35:52); ledger and Specification say `in_progress`: the render read data older than the transition | the hub shows the ledger state; cohort with CRP-382 (live data, no baked render) |
