# Specification: BUG-365

Module: docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Specification BUG-365.md  
Purpose: Line Ending Convergence Across Workspace  
Path: LCM_Inventory/docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Specification BUG-365.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Completed  
Date: 2026-11-19 11:47:30

```yaml
Bug-ID: BUG-365
CRP-ID: BUG-365
Title: Line Ending Convergence Across Workspace
Scope: Workspace (all repositories under the git root)
Version: 10.7.4
Affected-Repos: LCM_Inventory, LCM_AI, Git_Repositories, AuthorizeMasterUser, BGMSAMVInv, BackgroundModifier, BootEntryManager, HaSSD06, HaSSD06_Inventory, InstallFonts, LCM_Shared, LCM_Supervision, LCM_Tools, MSG file conversion, MacriumTemplateUpdater, NextBootTray, OneDriveMaintenance, OutlookVBAConversion, ReEnableRadeonRx580, RollingCalendar, SystemConfiguration, TimeStamper, VolumeInventory
Author: Claude
Date: 2026-11-19 11:47:30
Status: Completed
Plan-State: completed
Progress-State: completed
Severity: High
Root-Cause: The operator decision Option B (2026-11-16) never reached the canonical rule; six enforcers applied three different policies.
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Line endings flip-flopped between LF and CRLF. Target state: one table by file type, applied identically by every enforcer, and a one-time conversion of all text files under `D:\Git_Repositories`.

Operator 2026-11-19: "DO IT IMMEDIATELY. This change can't possibly break any rules and only improve our situation." and "no gate, just DOIT" (recorded as IMMEDIATELY, RULE-LCM-008 / RULE-REV-001 exception 1). Re-signing a signed script is pure maintenance, not a breaker.

## 2. Evidence of Flip-Flop (2026-11-19)

| Enforcer | Policy found |
|:---|:---|
| Canonical rule `InvariantRules.md` `newline-crlf` | CRLF for Windows text files |
| Operator Option B (2026-11-16, CRP-332 0a, WORKPLAN D-28) | LF, CRLF only `*.cmd` / `*.bat`; never written into the canonical rule |
| `.gitattributes` in LCM_AI, LCM_Inventory, LCM_Shared, LCM_Tools, LCM_Supervision, root | `* text=auto eol=crlf`: every checkout writes CRLF |
| HaSSD06 and 13 other repositories | no `.gitattributes` |
| VS Code `files.eol` (root and 7 repositories) | CRLF for new files |
| Claude hook + `LcmLineEndingAtoms.psm1` (also used by `Submit-ReviewResult.ps1`) | converted every written / committed file to CRLF |
| 76 of 187 PowerShell tools/modules | write CRLF (`Set-Content`, `Out-File`, explicit CRLF joins) |

Live during the fix: the old hook turned a new Python file into CRLF seconds after it was written; `Update-ToolCatalog.ps1` rewrote `tool_catalog.json`, `tool_intents.json` and `docs/README.md` to CRLF right after the conversion.

## 3. Target Table (canonical `newline-lf`)

- LF for every text file.
- CRLF only where a Windows-native consumer mis-parses LF: `*.cmd`, `*.bat`, ANSI `*.reg`, VBA exports `*.bas`, `*.cls`, `*.frm`.
- Untouched: binary and UTF-16 files (UTF-16 `*.reg`), live logs `*.log` / `*.jsonl` (a running writer could leave NUL gaps), vendor-signed `Activate.ps1` / `Activate_py.ps1` (no certificate to re-sign).
- Single policy source: `LCM_Inventory/tools/Repair-LcmLineEndings.py`.

## 4. Non-Goals

- Rewriting the 76 PowerShell writers now (they are rewritten in Python when touched; operator 2026-11-19).
- Converting live logs.
