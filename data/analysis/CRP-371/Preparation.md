# CRP-371 Preparation: References Relative To The Git Root

Module: data/analysis/CRP-371/Preparation.md  
Purpose: CRP-371 Preparation: References Relative To The Git Root  
Path: LCM_Inventory/data/analysis/CRP-371/Preparation.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:27:06

---

## 1. Inventory (absolute git-root paths, tracked files, without data/, logs/, scratch/, bundles)

| Repository | Files | Lines | By extension (lines) |
|:---|---:|---:|:---|
| LCM_AI | 77 | 348 | .md 281, .txt 40, .json 25, .ps1 2 |
| LCM_Inventory | 125 | 405 | .ps1 159, .json 98, .md 63, .psm1 63, .py 14, .go 3 |
| LCM_Shared | 11 | 16 | .md 9, .psm1 6, .json 1 |
| LCM_Supervision | 7 | 9 | .ps1 5, .md 4 |
| LCM_Tools | 19 | 45 | .ps1 31, .json 7, .cmd 4, .md 3 |

Largest files:

| File | Lines |
|:---|---:|
| `LCM_AI/docs/Implementation.md` | 27 |
| `LCM_AI/docs/LCM_Rules.txt` | 20 |
| `LCM_AI/docs/LCM_Rules_Gemini_Export.md` | 20 |
| `LCM_AI/docs/LCM_Rules_Gemini_Export.txt` | 20 |
| `LCM_AI/docs/Workspace Conventions.md` | 20 |
| `LCM_Inventory/config/tool_intents.json` | 55 |
| `LCM_Inventory/config/tool_catalog.json` | 33 |
| `LCM_Inventory/tools/Show-LcmActiveLauncher.ps1` | 19 |
| `LCM_Inventory/tools/Set-GitRoot.ps1` | 15 |
| `LCM_Inventory/modules/ProposalManager.psm1` | 13 |
| `LCM_Shared/docs/LoggingConvergence-proposal.md` | 5 |
| `LCM_Shared/Modules/PrivatePaths.psm1` | 2 |
| `LCM_Shared/AGENTS.md` | 1 |
| `LCM_Shared/GEMINI.md` | 1 |
| `LCM_Shared/Modules/BcdAtoms.psm1` | 1 |
| `LCM_Supervision/tools/Invoke-SupervisionRunner.ps1` | 2 |
| `LCM_Supervision/tools/Test-RepoReadiness.ps1` | 2 |
| `LCM_Supervision/AGENTS.md` | 1 |
| `LCM_Supervision/docs/Architecture.md` | 1 |
| `LCM_Supervision/docs/Implementation.md` | 1 |
| `LCM_Tools/tools/LCM_StructureFix-Post-cleanup.ps1` | 7 |
| `LCM_Tools/tools/ReplaceByJunction_History.json` | 7 |
| `LCM_Tools/tools/ReplaceByJunction.ps1` | 5 |
| `LCM_Tools/tools/Invoke-LcmRepositoryNamingMigrationStaged.ps1` | 4 |
| `LCM_Tools/tools/LcmJunctionFixer.ps1` | 3 |

Also in scope from the CRP-366 open items (same files as bare-launch fixes): `LCM_Supervision/tools/Invoke-SupervisionRunner.ps1`
(2 absolute root paths, bare launch line 93); outside the five LCM repositories: `HaSSD06/tools/Register-BleSupervisionTask.ps1`
(2, line 58) and `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1` (7, bare launch strings lines 3110-3391).
`LCM_Inventory/modules/LcmToolCatalog.psm1` (9) contains the call-statistics writer that CRP-358 replaces.

## 2. Steps

1. Canonical rule (ADMINMODE, RULE-AUTH-002 sync) and a readiness check that reports new absolute in-root paths (CRP-373
   carries the gate change).
2. Code first, by repository, in batches of related tools: resolve the root at run time (`$PSScriptRoot`, `__file__`,
   executable location, explicit root parameter); syntax gate and tests per batch.
3. Documentation and examples (`file:///D:/...` links, help texts) mechanically to `LCM_Inventory/...` form.
4. Files that CRP-358 rewrites (catalog generator, sync engines, proposal manager, tool catalog module) are fixed inside
   those rewrites, not twice.

## 3. Dependencies

- After CRP-372 (rule edits then cause no formatting re-hash churn) and with or after CRP-374 (rewritten tools follow
  the language direction).
- Overlaps CRP-358 files; order inside CRP-358 decides those.

## 4. Operator Questions

1. Include `HaSSD06` and `HaSSD06_Inventory` (not in the five governed LCM repositories) in the repair, or only the five?
