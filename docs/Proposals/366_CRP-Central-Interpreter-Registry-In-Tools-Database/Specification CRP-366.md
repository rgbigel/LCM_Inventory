# Specification: CRP-366

Module: docs/Proposals/366_CRP-Central-Interpreter-Registry-In-Tools-Database/Specification CRP-366.md  
Purpose: Central Interpreter Registry In Tools Database  
Path: LCM_Inventory/docs/Proposals/366_CRP-Central-Interpreter-Registry-In-Tools-Database/Specification CRP-366.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 12:04:40

```yaml
CRP-ID: CRP-366
Title: Central Interpreter Registry In Tools Database
Scope: LCM_Inventory, LCM_AI (rules)
Version: 10.7.4
Affected-Repos: LCM_Inventory, LCM_AI, Git_Repositories
Author: Claude
Date: 2026-11-19 12:04:40
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Origin

Operator 2026-11-19, option B of the interpreter question: "record the interpreter path once centrally (in tools.db, like the AutoHotkey executable), with tools and trampolines reading it from there instead of hard-coding it". Includes option A: binding launch rule. Background: the machine has `py.exe` twice (Windows and the WindowsApps install manager), the `python3` Store stub, `pyw`, the base 3.14 install and the workspace venv; bare `python` resolves through PATH to the venv, `py` defaults to the venv.

## 2. Gate 0 Contract

- **Target state:** one registry (`tools.db` table `runtimes`) names the executable that runs LCM Python code; every LCM_Inventory launch takes it from there; the rule is canonical (RULE-PY-010).
- **Invariants:** no silent PATH fallback when the registry is readable; the catalog generation never aborts on bookkeeping (RULE-EFF-002: warning plus fallback); `tools.db` stays the authority and `tools.sql` carries the rows; no field of an existing table changes.
- **Exit criteria:** trampolines carry the absolute registered path; no bare `python` launch left in LCM_Inventory except the documented bootstrap; tests and parse clean; rule synced (RULE-AUTH-002).
- **Non-goals:** the subsystems' own launches (LCM_Tools, HaSSD06, HaSSD06_Inventory, LCM_Supervision; listed as open items); rewriting the touched PowerShell tools in Python; eliminating the JSON catalog (separate item).

## 3. Design

- Table `runtimes (runtime_key PK, executable_path, purpose, updated_at)`; seeds `python` = `D:\Tools\Python314\python.exe`, `python-venv` = workspace `.venv`.
- Reader `tools/Get-LcmRuntime.py` (`get` / `list` / `set`); PowerShell atom `Get-LcmRuntimePath`; bootstrap: any Python may run the reader, because the answer comes from the table.
- Trampolines do not use `-I` (four HaSSD06 tools import sibling modules; `-I` drops the script directory in 3.14). All 23 trampolined tools import only modules present in the base interpreter (checked).
