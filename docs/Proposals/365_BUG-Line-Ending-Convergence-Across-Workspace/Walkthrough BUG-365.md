# Walkthrough: BUG-365 - Line Ending Convergence Across Workspace

Module: docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Walkthrough BUG-365.md  
Purpose: Implementation and verification record for BUG-365.  
Path: LCM_Inventory/docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Walkthrough BUG-365.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 11:47:30

---

## 1. Verification (2026-11-19)

| Check | Result |
|:---|:---|
| Dry run before conversion (scratch scanner) | 4098 text files, 3169 to convert, 62 mixed, 2 signed (vendor `Activate*.ps1`) |
| `py_compile` + `flake8 --select=E9,F63,F7,F82,F401,F541,F841` (tool, test, hook) | 0 / 0 |
| `python -I -m unittest` `test_repair_lcm_line_endings.py` | 11 passed |
| `Submit-ReviewResult.ps1` AST parse | 0 errors |
| JSON / JSONC syntax of 9 VS Code settings and `.claude/settings.json` | ok |
| Apply pass 1 | converted 1898, failed 0 |
| Re-check | 92 left: files with doubled CR (`\r\r\n`); the tool collapsed one CR per pass |
| Tool fix | a run of CRs before LF is one line break; test `test_collapses_doubled_cr` added |
| Apply pass 2 | converted 104, failed 0 |
| Final dry run | would_convert 0 |
| `Update-ToolCatalog.ps1 -Silent` | exit 0; launcher points to `Repair-LcmLineEndings.py`; it rewrote 3 files to CRLF (writer evidence), corrected |
| `CANONICAL_HASHES.md` | 21 of 21 re-hashed |

## 2. Gate

Operator 2026-11-19: "no gate, just DOIT" (IMMEDIATELY); a line-ending change creates no review candidate (RULE-REV-001). Commit pending the operator's `COMPLETE` scope (Plan, open items).

## 3. Renormalization Commits (2026-11-19 12:33:55)

Operator 2026-11-19 option A: one-time commit per repository of the files whose only difference is line endings (direct
`git commit`, outside the governed tools; exception recorded here). Classification: HEAD blob and working file equal after
`\r+\n -> \n`; plus the BUG-365 enforcer files `.gitattributes` / `.vscode/settings.json`. Literal pathspecs, `--only`.

| Repository | Commits |
|:---|:---|
| AuthorizeMasterUser | 6e88ddd, b4cb56f |
| BGMSAMVInv | ec34b5e, 504a9d3 |
| BackgroundModifier | 16c807b |
| BootEntryManager | 30906d0, 4f1c221 |
| HaSSD06 | 1ae3ad7, 2fffb86 |
| HaSSD06_Inventory | 42b443d, c0a8c4b |
| InstallFonts | 32f5402 |
| LCM_Supervision | 451020c |
| LCM_Tools | 1b21504 |
| MSG file conversion | da554c3 |
| MacriumTemplateUpdater | aa2c472 |
| NextBootTray | a8bb8ec, cd50cac |
| OneDriveMaintenance | ffa53a0 |
| OutlookVBAConversion | 6c39024 (incl. 91 files with doubled CR) |
| ReEnableRadeonRx580 | 3a23d0f |
| RollingCalendar | d869fc9 |
| SystemConfiguration | d83494e, c1433ec |
| TimeStamper | 60fe61f |
| VolumeInventory | 22325fc, 8311626 |
| LCM_AI, LCM_Shared | nothing left (index already LF; files were only stat-dirty) |
| Git_Repositories (51), LCM_Inventory (896) | staged, verified line-ending-only; the pre-commit review gate blocks a direct commit and BUG-365 is `completed`, so they ride with the next governed COMPLETE of these repositories (Submit-ReviewResult continues an existing staged manifest) |

First pass defects (corrected in the second pass): tracked files under ignored directories need `git add -f`; untracked new
`.gitattributes` were not in the modified list.
