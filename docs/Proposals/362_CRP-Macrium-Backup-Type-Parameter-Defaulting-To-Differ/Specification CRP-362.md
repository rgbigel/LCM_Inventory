# Specification: CRP-362

Module: docs/Proposals/362_CRP-Macrium-Backup-Type-Parameter-Defaulting-To-Differ/Specification CRP-362.md  
Purpose: Macrium Backup Type Parameter Defaulting To Incremental  
Path: LCM_Inventory/docs/Proposals/362_CRP-Macrium-Backup-Type-Parameter-Defaulting-To-Differ/Specification CRP-362.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 23:49:34

```yaml
CRP-ID: CRP-362
Title: Macrium Backup Type Parameter Defaulting To Incremental
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 23:49:34
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-18: Start-MacriumDailyBackup.ps1 runs Reflect.exe -e <definition> without a backup type, so Reflect makes a full backup (many hours). New optional parameter -BackupType Full|Diff|Inc, default Diff, passed to Reflect as -full / -diff / -inc.
- DOIT by operator instruction 2026-11-18 ("doit for all"). Review: this Specification and the Walkthrough. Plan: none beyond this Specification.

## 2. Gate 0 Contract
### Target State
- T1 `Start-MacriumDailyBackup.ps1` has an optional parameter `-BackupType Full|Diff|Inc`, default `Inc` (operator 2026-11-19; first `Diff`); it is passed to Reflect as `-full`, `-diff` or `-inc`.
- T2 Help (`-h`) and header name the parameter and the default.

### Invariants and Exit Criteria
- Callers without the parameter get an incremental backup; `-BackupType Full` restores the previous behaviour.
- Exit: parse gate; test of the built Reflect argument list per type; one live differential run.

### Explicit Non-Goals
- Changing the Macrium definition file or its schedule.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
## Absorbed Operator Remarks

> it is doing a Full backup, that takes many hours. did you specify that? we would be a bit faster if we just did a differential backup.

> the tool you called should get that as an optional parameter defaulting to diff. This is a low prio new CRP

(Operator, 2026-11-18.)

> a minor, probaly just a text change: in crp 362, i used the wrong default . Modify this from Differential to Incremental for more speed. Do not test, IMMEDIATE, I accept  the result with all consequences

(Operator, 2026-11-19; default Inc; Gate 2 exception RULE-REV-001 (1).)
