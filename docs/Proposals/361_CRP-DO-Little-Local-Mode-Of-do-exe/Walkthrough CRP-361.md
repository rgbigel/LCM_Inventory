# Walkthrough: CRP-361 - DO-Little Local Mode Of do.exe

Module: docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Walkthrough CRP-361.md  
Purpose: Implementation and verification record for CRP-361.  
Path: LCM_Inventory/docs/Proposals/361_CRP-DO-Little-Local-Mode-Of-do-exe/Walkthrough CRP-361.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:01:23

---

## 1. Verification (2026-11-19)

| Check | Result |
|:---|:---|
| `gofmt -l` (changed files), `go vet ./...`, `go test ./...` | clean / clean / ok (TestRouteDecision: one case per T2 row; TestLocalNeverElevates) |
| `-explain` with the new binary | sync terminal -> local; window on own desktop -> local; elevated atom -> daemon; `-elevated` -> daemon; `-daemon` -> daemon |
| Local sync run `whoami /groups` | Medium Mandatory Level (caller's rights) |
| Shared log form | `do_activity.log`: local and daemon lines identical in form (Path, Caller, Status, ExitCode, Duration, Elevated, Decision) |
| Daemon stopped | local call works; `-elevated` call fails with "this call needs the daemon (...) ... it does not run locally instead"; daemon restarted |
| Deployment | task `\LCM_DesktopDaemon_rgbig` restarted; `status` 10.2.8, session 1; `POST /open_editor` -> 405 (route gone, catch-all) |
| Inline script of `LCM_INVENTORY_VIEWER.html`, `lcm-tool-explorer.js` | `node --check` ok; inventory display re-rendered |
| `test_set_lcm_window_zone.py` incl. live test (own Notepad window placed left, checked, closed) | 5 passed |
| Catalog / tools.db | `SetLcmWindowZone.cmd` with the registered interpreter; intents `set-lcmwindowzone`, `setlcmwindowzone` |
| Rows not reproducible live (non-elevated session 1): elevated caller, caller without desktop | covered by the unit tests |

## 2. Review Corrections (operator Gate 2, 2026-11-19 16:56:41)

- References inside the git root are relative to it (CRP-253 sandboxing): `GetGitRoot()` derives the root from the binary location (`<root>/LCM_Inventory/DoT/do.exe`) instead of a fixed `D:` path; rebuilt, `go test` ok, deployed (rollback `scratch/do-before-crp361-seg3.exe`), local and daemon path answer.
- Runtime `python-venv` stored relative (`.venv\Scripts\python.exe`) and resolved by `Get-LcmRuntime.py`; `python` (machine tool outside the root) stays absolute; `tools.sql` dumped; Pester LcmRuntimeAtoms 3/3.
- DOX header Markdown line breaks fixed in 137 files and in the bundle template (`ProposalManager.psm1`).

## 3. Operator Live Test (2026-11-19 23:48:45, VS Code terminal)

| # | Step | Result |
|:---|:---|:---|
| 1 | `do.exe "whoami" -sync -explain` | route local: passed |
| 2 | `do.exe "whoami" -sync -elevated -explain` | route daemon: passed |
| 3 | `do.exe "whoami /groups" -sync` | local run, Medium integrity: passed |
| 4 | `do.exe "whoami" -sync -daemon` | daemon run: passed |
| 5 | `do_activity.log` last two lines | same form, Path local / daemon: passed |
| 6 | `SetLcmWindowZone --process notepad++.exe --zone beside:"Visual Studio Code"` | Notepad++ moved to the right half and enlarged (fallback: less than 400 px right of VS Code); not brought to the foreground, as specified (placement only, `SWP_NOACTIVATE`): passed |

Note: in PowerShell `do` is a keyword; the launcher is called as `do.exe`.
| 7 | Control Hub, action selector at the top: "Show CRP" (Notepad++ through the DO, T5 path) | works (operator 2026-11-19 23:58:24) |
| 8 | Tool Explorer start (`Show-ToolsExplorer.ps1`) | started from my background shell it did not open (refresh 7 s, `Open-LcmStandardDisplay` waits 5 s); on the operator's side it opened very quickly; operator: the 5 s timeout stays, no BUG |
| 9 | Inventory Viewer, Docs of LCM_AI, "Edit" (Notepad++ through the DO, T5 path) | works; Show, document type selection and Close work too; findings about the viewer itself in BUG-380 (operator 2026-11-20 00:20:32) |
