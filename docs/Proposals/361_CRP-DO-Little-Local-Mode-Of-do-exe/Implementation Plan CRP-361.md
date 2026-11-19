# Implementation Plan: CRP-361 - DO-Little Local Mode Of do.exe

Module: docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Implementation Plan CRP-361.md  
Purpose: Concrete changes per file for CRP-361 and its open items.  
Path: LCM_Inventory/docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Implementation Plan CRP-361.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:01:23

---

## 1. Segments (DOIT, operator 2026-11-19)

| Seg | Target | Files | Status |
|:---|:---|:---|:---|
| 1 | T2 route decision, T3 local path with the caller's own token, T4 one log format | `src/do/route.go` (new), `route_test.go` (new), `client.go`, `daemon.go`, `types.go` (10.2.8); `DoT/do.exe` deployed | done |
| 2 | T5 external tools start as themselves; `/open_editor`, `/edit`, `OpenRequest.pane` removed; `/api/action` accepts `options.windowStyle` | `daemon.go`, `types.go`, `assets/LCM_INVENTORY_VIEWER.html` 10.2.2 (Notepad++ via DO), `assets/lcm-tool-explorer.js` 10.0.4 (VS Code via DO) | done |
| 3 | T6 window-placement atom | `tools/Set-LcmWindowZone.py` (new, Python ctypes), `tests/test_set_lcm_window_zone.py` (new); intent `set-lcmwindowzone`, trampoline `SetLcmWindowZone.cmd` | done |

## 2. Open Items

- T1 (one entry point): callers that still start tools without `do.exe` move to it when they are touched or rewritten; no big-bang migration (operator direction 2026-11-19). Not part of the exit criteria.
- T4 intent call statistics: the DO does not record them yet. The only other writer is `Update-LcmToolIntentCall` (`modules/LcmToolCatalog.psm1`), called by the legacy PowerShell daemon controller and by tests; the tests write into the live store (BUG-375). T4 follows the elimination of the JSON table copies (CRP-358); then the DO records the statistics for both paths in the table and `Update-LcmToolIntentCall` is aligned or retired.
- Live operator tests (Gate 2): Control Hub "Edit in Notepad++" (already a direct DO start since CRP-354), inventory viewer "Edit", Tool Explorer "Code editor", and `do SetLcmWindowZone --process notepad++.exe --zone beside:"Visual Studio Code"`.
- Wiring the placement into the Notepad++ buttons (always place beside VS Code?) is the operator's choice; not done.
- Rollback copies: `LCM_Inventory/scratch/do-before-crp361.exe` (before the CRP), `do-before-crp361-seg2.exe` (before segment 2).
- New tool `Set-LcmWindowZone.py` is at admin level 0 (TBD) like every new tool; level 1 (granted) is the operator's catalog decision.

## 3. Segment 4 (decided by the operator 2026-11-19, implemented after the Gate 2 accepts)

- Asynchronously started Python tools: the starting process watches the started process; its exit code goes into the DO log; on failure the window stays open (exit code and error, closes on a key press) and a Windows notification appears; on success the window closes as before.
- `-noexit` stays the PowerShell debugging switch, unchanged; GUI programs unchanged.
