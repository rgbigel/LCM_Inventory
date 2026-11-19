# Combined Plan: CRP-358, 363, 369, 371, 372, 373, 374 and the CRP-366 Open Items

Module: data/analysis/CRP-358/Combined-Plan.md  
Purpose: Combined Plan: CRP-358, 363, 369, 371, 372, 373, 374 and the CRP-366 Open Items  
Path: LCM_Inventory/data/analysis/CRP-358/Combined-Plan.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:31:46

---

## 1. Recommended Sequence

| # | Item | Why here | Shares files with |
|---:|:---|:---|:---|
| 1 | CRP-369 VS Code settings | independent, small | none |
| 2 | CRP-372 normalized rule hashes | removes re-hash churn before the rule changes | goodmorning skill, CANONICAL_HASHES.md |
| 3 | CRP-374 language direction + PowerShell pitfalls (rules) | later rewrites follow it | canonical rules, AGENTS.md, Cross-Reference, adapter |
| 4 | CRP-371 step 1: git-root rule + checker | later code changes must not add absolute paths | canonical rules, readiness gate (with CRP-373) |
| 5 | CRP-358 strategies.json | smallest store, identical data | `Test-LcmStrategyConsistency.ps1` (rewrite in Python here) |
| 6 | CRP-363 atom design final (decided 2026-11-19 except the required-switch field) | the tools.db schema changes once | DataDesign-Tools.md, `data/analysis/CRP-363/DataDesign-Atoms-Draft.md` |
| 7 | CRP-358 tool_intents.json + tool_catalog.json, incl. CRP-363 tables | generator writes tables; statistics writer replaced | Update-ToolCatalog.ps1, sync_tool_catalog_db.py, LcmToolCatalog.psm1, tests |
| 8 | CRP-358 proposals.json (tables per `DataDesign-Proposals-Catalog-Draft.md`; the 117 JSON timestamps of 2026-10-13 applied) | largest, most readers | ProposalManager.psm1 and 31 files |
| 9 | CRP-371 step 2: repair of the remaining absolute paths | files touched by #5-#8 already fixed there | 240 files |
| 10 | CRP-363 ShowAtoms + ShowToolIntents | needs the tables of #7 | Show-ToolIntents.ps1 |
| 11 | CRP-373 readiness completeness | covers the rules of #2-#4 and #9 | Test-RepoReadiness.ps1, tests |

## 2. CRP-366 Open Items: Owner

| Item | Files | Owner | Slot |
|:---|:---|:---|:---|
| Bare launches, LCM repositories | `LCM_Tools/tools/@Repair_Diagnose-OneDriveSync.ps1`, `@Repair_Test-OneDriveSync.ps1` (lines 343, 483), `LCM_Supervision/tools/Invoke-SupervisionRunner.ps1` (93) | CRP-371 step 2 (same pass over these files) | #9 |
| Bare launches, HaSSD06 subsystems | `HaSSD06/tools/Register-BleSupervisionTask.ps1` (58), `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1` (10 strings, 3110-3391) | CRP-371 if the operator includes the subsystems (CRP-371 question 1), else a subsystem item | #9 |
| Inline `-c`: `Test-LcmStrategyConsistency.ps1` | reads the strategies tables | CRP-358 strategies step (Python rewrite) | #5 |
| Inline `-c`: `tests/ToolPermissionLevels.Tests.ps1` | tools.db levels | CRP-358 tools step (with CRP-363) | #7 |
| Inline `-c`: `Archive-Clean.ps1`, `Archive-Conversations.ps1` | conversation archive queries | CRP-374 direction, rewritten when next touched; listed in CRP-374 | after #3 |

## 3. Statistics Writer (finding)

`Update-LcmToolIntentCall` (`LCM_Inventory/modules/LcmToolCatalog.psm1`, line 943) increments `call_count`,
`last_called_at`, `last_duration_ms`, `total_duration_ms` directly in `config/tool_intents.json` (fixed drive path).
Callers: the legacy PowerShell daemon controller (`modules/LcmDaemon/Classes/DaemonActionController.ps1`, lines 238 and
326, loaded by `tools/LcmDesktopDaemon.ps1`, not by the running Go daemon) and two test files
(`tests/ToolIntentMetrics.Tests.ps1` against the live file; `tests/LcmElevatedDaemon.Tests.ps1` through the controller).
The newer statistics seen by the reconciliation come from the gate's test runs. In CRP-358 slot #7 the writer moves to
the table (and to the DO, CRP-361 T4); the live-store writes of the tests are a test-isolation defect (CRP-373 question 1).

## 4. Operator Answers (2026-11-19) And Open Questions

Answered: old timestamps: the JSON batch times win for `pushed_at` (88) and `created_at` (29) of the 2026-10-13 items
(exception to "table wins", these 117 values only); data design for proposal settings, review cohorts, review
obligations and the catalog fields drafted (`DataDesign-Proposals-Catalog-Draft.md`); atoms 1:n with an own key,
permissions by atom, full call graph (atoms draft revision 2); the test writing live statistics is BUG-375.

Open:

1. CRP-363: required switch as an explicit catalog field, or derived from the parameter column?
2. CRP-369: move `powershell.pester.pesterVersion` / `powershell.scriptAnalysis.enable` (AuthorizeMasterUser only) into
   the root file or drop them?
3. CRP-371: include HaSSD06 and HaSSD06_Inventory?
4. CRP-372: helper location (`LCM_AI/.claude/` or `LCM_Inventory/tools/`)?
5. CRP-373: the test-isolation part is BUG-375; does CRP-373 still need it in its scope (proposed: no, reference only)?
6. CRP-374: new rule IDs or extensions of existing ones?
