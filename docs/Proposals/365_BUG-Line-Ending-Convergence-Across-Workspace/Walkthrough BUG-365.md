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
