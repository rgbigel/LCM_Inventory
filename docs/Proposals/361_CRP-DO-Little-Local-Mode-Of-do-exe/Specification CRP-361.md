# Specification: CRP-361

Module: docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Specification CRP-361.md  
Purpose: DO-Little Local Mode Of do.exe  
Path: LCM_Inventory/docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Specification CRP-361.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Completed  
Date: 2026-11-18 20:24:06

```yaml
CRP-ID: CRP-361
Title: DO-Little Local Mode Of do.exe
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 20:24:06
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

- Every call goes through `do.exe`; `do.exe` decides whether the daemon is needed. Simple calls (same rights, same desktop) run locally; the daemon stays the back end for the cases only it can serve.
- Why: more control (one entry point, one log, one intent registry) without the daemon's cost for simple cases (round trip, key, token duplication, dependency on a running daemon).
- Relation to CRP-343: CRP-343 segment 2 provides the decision function this CRP reuses; planned back-to-back (operator 2026-11-18).
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract

### Target State

T1 One entry point: tools, the AI host and scripts start registered intents and external tools through `do.exe` (or its PowerShell client `LcmDoClient.psm1`).

T2 Local or daemon, decided by `do.exe` with the CRP-343 decision function:

| Case                                                    | Path                  |
|:--------------------------------------------------------|:----------------------|
| same rights as the caller; terminal or its own desktop  | local (`do.exe`)      |
| request from a browser page                             | daemon                |
| elevated atom                                           | daemon                |
| elevated caller starts a non-elevated atom              | daemon                |
| caller without a desktop needs a window                 | daemon                |

T3 The local path never grants more than the caller already has; elevation stays exclusive to the daemon.

T4 Both paths log in one format (intent, caller, path taken, result, duration) and update the same intent call statistics.

T5 External tools are started as themselves (e.g. `notepad++.exe <file>`), never through an editor route; the daemon route `/open_editor` and the dead display `pane` parameter are removed (CRP-343 T5 removes the legacy carriers).

T6 Window-placement atom: a registered intent places a started window in a named screen zone (first case: Notepad++ next to VS Code).

### Invariants and Exit Criteria

- The decision function exists once and is compiled into client and daemon; no second copy.
- Simple calls keep working while the daemon is down; daemon-only cases fail with a clear message, never silently locally.
- Exit: a test per T2 row shows the path taken; local and daemon log lines are identical in form; "Edit in Notepad++" in the Control Hub opens Notepad++; the placement atom places Notepad++.

### Explicit Non-Goals

- Embedding foreign windows into VS Code panes (not feasible with Electron; placement instead).
- Changing the elevation decision itself (CRP-343).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
## Absorbed Operator Remarks

> There is the basic question if we can "afford" DO-little. the intent is to have more control, but keep things simple for simple cases (eg. when no elevation is needed at all, any pure terminal work). At times where we do not intereact outside of a pane, why bother to use the more complex DO path? Third alternative: the DO could also have a mode that short-cuts the DO, so it actually just "talks" to a local variant of the  DO Frontend that now is the needed for complicated matters. Think out of the box.

> just a question to make me wiser: panes usable for normal windows? it would be nice to see notepad++ in a pane. wishfull thinking...

> A, register DO-Little as new CRP. but think of this as an intended goal that crp 343 makes simpler rather than more complex. we will do them back-to-back if possible

(Operator, 2026-11-18.)
