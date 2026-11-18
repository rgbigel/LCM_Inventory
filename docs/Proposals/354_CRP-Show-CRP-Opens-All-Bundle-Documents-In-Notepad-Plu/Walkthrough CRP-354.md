# Walkthrough: CRP-354 - Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs

Date: 2026-11-18 21:26:32

## 1. Path taken and issues on the way
- Correction of Specification section 4 / T3: the rendered preview is not only reached through the removed actions; "Show Repo Docs" (Architecture diagrams) uses the same document window. Because the other document items are not part of this CRP (Q1), the preview and the window stay; "Show CRP" does not use them. The window's "Edit in Notepad++" button still opens VS Code (`/open_editor` runs `code -g`); left for a separate decision.
- The existing `executeDaemonCommand` sends `sync: true`; for a newly started Notepad++ the Control Hub would wait until Notepad++ is closed. "Show CRP" therefore sends its own DO call with `sync: false` (fire-and-forget).
- No daemon (Go) change: the existing `/api/action` route runs the command non-elevated with the workspace root as working directory, so relative bundle paths work.
- Scope amendment T5 (labels) added on operator instruction during implementation; "the latter should be 2 - Review" read as the `in_review` label.
- First patch run stopped before writing: one anchor (12-space option line) was a substring of another (14-space); order swapped.

## 2. Verification evidence (2026-11-18 15:27:39)
- JavaScript syntax: the three inline scripts of the template pass `node --check` (the second one is the JSON data block).
- No reference to the removed actions remains (`showProposalSpec|Plan|Walkthrough|Diff`, `show_spec`: 0); 15 references to "Show CRP" / `showProposalBundle`.
- `Show-LcmControl.ps1 -NoLaunch`: "Dashboard rendered cleanly".
- Live: the exact command "Show CRP" builds for CRP-354, sent through the DO (`Elevated: false`), opened the three documents as Notepad++ tabs (window title shows the full Walkthrough path, i.e. relative paths resolved).
- Check of the removed functions (operator request 2026-11-18): the three Show functions only displayed a cached document and offered the editor button; no ledger, log or other side effect. "Show Diff / BC Review" called `tools/Invoke-BeyondCompareReview.ps1`, which no longer exists, so it was already broken. One loss: their fuzzy search by number also found documents of closed legacy items without a recorded `bundle_dir` (163 items; 21 unreferenced bundle folders and 96 flat files remain in `docs/Proposals`); "Show CRP" uses only `bundle_dir`. All open items have a `bundle_dir`.
- Hidden test dependencies found and updated: `tests/ControlHubSafety.Tests.ps1` (row menu order looked for `showProposalSpec`; label "Committed - Ready to Push") and `tests/ProposalLifecycle.Tests.ps1` (label "2 - REVIEW"). Result: `ControlHubSafety` + `ProposalLifecycle` 53 passed, 8 failed; all 8 are pre-existing (3 lifecycle module cases as before; 5 ControlHubSafety cases whose expected texts do not match the committed HEAD template either, test file unchanged since 2026-11-10).
- Operator decision 2026-11-18 on the legacy-document gap: B, history stays unchanged (no fallback search for closed items without `bundle_dir`).
- Not yet clicked in the browser: the button itself (operator live test at Gate 2; refresh the Control Hub page first).

## 3. Revision 2 (2026-11-18 20:03:51)

- Operator live test: "Show CRP" works; "Edit Original CRP" opened an empty VS Code window.
- Cause: its fallback picked any bundle file not named `Specification.md` / `Implementation_Plan.md` / `Walkthrough.md`; since CRP-359 that is `Specification <ID>.md`, which went to `/open_editor` (VS Code) instead of an original CRP that no longer exists.
- Change: button, `openOriginalProposalInEditor` and `getOriginalProposalDocumentKey` removed (template 10.2.7 -> 10.2.8); `openProposalDocInNotepad` stays (used by the document modal). Test `ControlHubSafety.Tests.ps1` now asserts the absence.
- Evidence: `node --check` both inline scripts OK; no doubled CR; no remaining caller; `ControlHubSafety` 6 passed, 5 failed - the same 5 pre-existing cases (the edited case fails only on its old `prio === 0` assertion).
- Not changed: the document modal's "Edit in Notepad++" button calls `/open_editor`, which opens VS Code (label and behaviour differ); outside this revision, noted for the operator.

## 4. Operator changes at Gate 2 (2026-11-18 20:51:16)

- Kept: rendered preview, Show Repo Docs, Show Review Receipt, Show State History (nothing removed).
- Editor buttons: `openProposalDocInNotepad` and the activity-log button no longer call `/open_editor` (VS Code); all three editor paths and "Show CRP" send `pwsh -NoProfile -File LCM_Inventory\tools\Open-LcmNotepadPlusPlus.ps1 <files>` through the DO (template 10.2.8).
- Foreground: the new tool opens the files, then runs the new registered AHK atom `activate-window` (`tools/automation/Activate-Window.ahk`, non-elevated): Windows does not let a program started by the background daemon take the foreground by itself.
- Catalog: `Update-ToolCatalog.ps1` + `Sync-LcmToolCatalogDb.ps1`: intents `open-lcmnotepadplusplus`, `activate-window` (both `elevated = false`).

| Check                                   | Result                                              |
|:----------------------------------------|:----------------------------------------------------|
| Parse gate (tool, tests)                | 0 errors                                            |
| `node --check` both inline scripts     | OK; no doubled CR                                   |
| `OpenLcmNotepadPlusPlus.Tests.ps1`      | 5/5 (paths, registration, atom exits 2 and 3)       |
| `ControlHubSafety.Tests.ps1`            | 6 passed, 5 failed: the same 5 pre-existing cases   |
| Live, through `do.exe -sync`            | 3 CRP-354 documents opened; foreground VS Code -> Notepad++ |


## 5. Direct launch and daemon foreground (2026-11-18 21:19:21)

- Path taken: the PowerShell launcher of section 4 opened a console window and the AHK atom was an indirection; both removed (`tools/Open-LcmNotepadPlusPlus.ps1`, `tools/automation/Activate-Window.ahk`, their test file; catalog regenerated).
- The daemon already had `/foreground`; its plain `SetForegroundWindow` was refused by the Windows foreground lock (live: window found, VS Code stayed in front). Now it attaches to the input thread of the current foreground window, then `BringWindowToTop` + `SetForegroundWindow`, and checks the result; `waitMs` waits for a window that is still starting (`src/do/winutil.go`, `types.go`, `daemon.go` 10.2.5).
- Control Hub (template 10.2.9): `notepad++.exe` through `/api/action`, then `/foreground` with the file name and `waitMs: 10000`.
- Daemon redeployed; rollback copy `scratch/do-before-crp354.exe`.

| Check                                          | Result                                         |
|:-----------------------------------------------|:-----------------------------------------------|
| `gofmt` (changed files), `go vet`, `go test` | clean, clean, ok (`main.go` gofmt: BUG-348)   |
| `node --check` both inline scripts            | OK; no doubled CR                              |
| `ControlHubSafety.Tests.ps1`                   | 6 passed, 5 failed: same 5 pre-existing cases  |
| Live, old daemon: launch + `/foreground`       | found, not activated (VS Code stayed in front) |
| Live, new daemon: launch + `/foreground`       | found, active: VS Code -> Notepad++ (twice)    |
| Live, new daemon: `/foreground` VS Code         | VS Code back in front                          |
| Console windows during launch                  | none                                           |

## 6. Guided live test results (2026-11-18 21:26:32)

| No | Check                                              | Result                                                  |
|:--:|:---------------------------------------------------|:--------------------------------------------------------|
| 1  | Wizard menu entries                                | "Show CRP" twice (top and Documents) -> Documents entry removed |
| 2  | "Show CRP" (CRP-361)                               | working                                                 |
| 3  | Show Review Receipt -> Edit in Notepad++           | worked as expected                                      |

- Cause of 1: the operator's earlier remark ("the documentation section should not have a duplicate+1 action any longer; the top element is a good choice") was read as "Edit Original CRP" only; T2 had kept the second "Show CRP" by design. Template still 10.2.9 (same uncommitted cycle); `ControlHubSafety` asserts exactly one row entry.
- Found on the way: appended text from my patch scripts carried CR CR LF line ends into four bundle documents (CRP-354 Specification and Walkthrough, CRP-343 Walkthrough, CRP-361 Specification; the last two already in commit f828dba); repaired, patch helper now normalizes after every edit; scan of all bundle documents changed today: no lone CR left.
