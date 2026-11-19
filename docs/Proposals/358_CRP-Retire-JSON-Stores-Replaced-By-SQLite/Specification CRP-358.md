# Specification: CRP-358

Module: docs/Proposals/358_CRP-Retire-JSON-Stores-Replaced-By-SQLite/Specification CRP-358.md  
Purpose: Retire JSON Stores Replaced By SQLite  
Path: LCM_Inventory/docs/Proposals/358_CRP-Retire-JSON-Stores-Replaced-By-SQLite/Specification CRP-358.md  
Authors: Rolf  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:18:18

```yaml
CRP-ID: CRP-358
Title: Retire JSON Stores Replaced By SQLite
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:41:02
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic C): JSON is the authority in practice although RULE-LCM-001 names proposals.db. Retire in order: strategies.json, tool_intents.json, tool_catalog.json, proposals.json (last; cohorts, obligations and settings are missing in the DB). Each step: read-only reconciliation report (key sets, field comparison, settings) under data/analysis, operator decision, schema additions, store accessor switched to SQLite, JSON deleted in the same change set as its writers.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
T1 The SQLite tables are the only store: proposals.db for the ledger and strategies, tools.db for tools, intents and atom permissions; the catalog generator and every other writer write the tables directly.

T2 One-time reconciliation per JSON file against its table; in a dispute the table wins (operator 2026-11-19).

T3 After the reconciliation no tool reads or writes the JSON file again, and it is physically deleted in the same change set as its last reader and writer ("as soon as possible", operator 2026-11-19).

### Invariants and Exit Criteria
- No ledger or table field is dropped (archive by marking); an SQL dump is taken before any table restructuring.
- Every switched reader and writer passes its syntax gate and tests; the reconciliation report per file is kept under data/analysis.
- Exit: none of the four JSON files exists; a search finds no code reading or writing them.

### Explicit Non-Goals
- Generated presentation artifacts that merely embed data (displays); the policy export elevation_policy.json for the daemon (no SQLite driver in Go) unless decided otherwise.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

### Dependents
- CRP-361 T4 (intent call statistics), CRP-363 (atom data design), CRP-369 (planned together).

## Absorbed Operator Remarks

> another problem resulted from using the old version of SQLite tables which were represented as .json files. As per a previous CRP, i had already asked to to a one - time match, giving preference to the tables in case of "dispute", AND THEN NEVER TO USE THE .json FILES AGAIN. They should be eliminated physically as soon as possible.

(Operator, 2026-11-19.)

## Operator Decisions (2026-11-19 17:29:38)

1. Old timestamps (2026-10-13 items): for `pushed_at` (88 rows) and `created_at` (29 rows) the JSON batch times win; the
   table is corrected to the JSON values before `proposals.json` is deleted (exception to "the table wins", these
   117 values only).
2. Missing tables: draft the data design for proposal settings, review cohorts, review obligations and the catalog fields
   `Aliases`, `Role`, `Domain`, `IntentElevated` (read-only draft under `data/analysis/CRP-358/`).
3. Intent call statistics: the writer `Update-LcmToolIntentCall` (`modules/LcmToolCatalog.psm1`) moves to the table with
   the tool stores; tests writing into the live store are BUG-375.
