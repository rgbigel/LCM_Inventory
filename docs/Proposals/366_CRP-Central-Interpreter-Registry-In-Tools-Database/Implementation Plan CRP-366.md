# Implementation Plan: CRP-366 - Central Interpreter Registry In Tools Database

Module: docs/Proposals/366_CRP-Central-Interpreter-Registry-In-Tools-Database/Implementation Plan CRP-366.md  
Purpose: Concrete changes per file for CRP-366 and its open items.  
Path: LCM_Inventory/docs/Proposals/366_CRP-Central-Interpreter-Registry-In-Tools-Database/Implementation Plan CRP-366.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 12:04:40

---

## 1. Changes (done 2026-11-19)

| File | Change | Gate 0 clause |
|:---|:---|:---|
| `tools/sync_tool_catalog_db.py` 10.2.6 | `ensure_runtimes()` (DDL + seed), called by `init_db`; SQL dump carries `runtimes` | target state, invariants |
| `tools/Get-LcmRuntime.py` (new) | Registry reader / setter | target state |
| `modules/LcmRuntimeAtoms.psm1` + `tests/LcmRuntimeAtoms.Tests.ps1` (new) | `Get-LcmRuntimePath`, 3 Pester cases | target state |
| `tools/Update-ToolCatalog.ps1` 10.2.12 | Trampolines and examples use the registered path; warning + `python` fallback if unreadable | exit criteria, invariants |
| `Sync-LcmToolCatalogDb.ps1`, `Invoke-ProposalAction.ps1`, `Invoke-LCM_Push.ps1`, `Invoke-LcmProtocol.ps1`, `Test-LcmStrategyConsistency.ps1`, `Submit-ReviewResult.ps1`, `LcmPushRequalification.psm1`, `DaemonActionController.ps1`, `ToolPermissionLevels.Tests.ps1`, `Archive-Clean.ps1`, `Archive-Conversations.ps1`, `Invoke-PrivilegedTool.ps1`, `Test-GeneralReadiness.ps1` | Bare `python` -> `Get-LcmRuntimePath` (patch bump, Implementation Choices line) | exit criteria |
| `docs/DataDesign-Tools.md` 10.2.4 | Section 2.2 `runtimes` | RULE-DOC-012 |
| `LCM_AI/.agents/rules/PythonRules.md` 10.2.1 | RULE-PY-010 interpreter-registry (ADMINMODE on) | target state |
| Claude adapter `PythonRules.md`, root `AGENTS.md`, `LCM-Rules-Cross-Reference.md`, `CANONICAL_HASHES.md` | RULE-AUTH-002 sync | target state |

## 2. Open Items

- Bare launches outside LCM_Inventory (non-goal now, fix when the tool is touched or rewritten): LCM_Tools `@Repair_Diagnose-OneDriveSync.ps1` / `@Repair_Test-OneDriveSync.ps1` (4), LCM_Supervision `Invoke-SupervisionRunner.ps1` (1), HaSSD06 `Register-BleSupervisionTask.ps1` (1), HaSSD06_Inventory `Show-HaInventoryApp.ps1` (10 `defaultCmd` strings).
- `Test-LcmStrategyConsistency.ps1`, `Archive-Clean.ps1`, `Archive-Conversations.ps1`, `ToolPermissionLevels.Tests.ps1` embed Python as inline `-c` code: Python-rewrite candidates (RULE-PY-010 ad-hoc clause, operator direction 2026-11-19).
- Windows Store aliases `python.exe` / `python3.exe` (option C) are an operator setting; not part of this CRP.
- Backup `LCM_Inventory/scratch/db-dumps/tools-before-crp366.db`: delete after the completion checks.
