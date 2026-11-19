# CRP-358 Reconciliation: tool_intents.json

Module: data/analysis/CRP-358/tool_intents.md  
Purpose: CRP-358 Reconciliation: tool_intents.json  
Path: LCM_Inventory/data/analysis/CRP-358/tool_intents.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (CRP-358 phase 1, read-only)  
Date: 2026-11-19 17:22:28

---

Method: databases opened read-only (`mode=ro`); JSON files read only; nothing was changed. Reader/writer classification is a file-level heuristic (write / read operations present in a file that names the store); a path that is passed to another module is listed as "reference".

## 1. Store

- JSON: `LCM_Inventory/config/tool_intents.json`
- Table(s): tools.db: tool_intents

## 2. Key Sets

| JSON keys | Table keys | Both | Only JSON | Only table |
|---:|---:|---:|---:|---:|
| 683 | 683 | 683 | 0 | 0 |

## 3. Field Differences (common keys; the table wins in a dispute, operator 2026-11-19)

| Field | Rows | Examples (key: JSON / table) |
|:---|---:|:---|
| `call_count` | 7 | show-toolintents: `13` / `12`; showtoolintents: `13` / `12`; submit-reviewresult: `25` / `23` |
| `last_called_at` | 7 | show-toolintents: `2026-11-19 16:03:13.589` / `2026-11-19 12:37:52.001`; showtoolintents: `2026-11-19 16:03:13.589` / `2026-11-19 12:37:52.001`; submit-reviewresult: `2026-11-19 16:02:11.822` / `2026-11-19 12:36:47.433` |

## 4. Data Without A Column

None.

## 5. Readers And Writers (11 files, 23 lines)

| File | Class (file level) | Lines |
|:---|:---|:---|
| `LCM_Inventory/modules/LcmAhkAtoms.psm1` | read | 14, 278, 282, 300, 306, 318 |
| `LCM_Inventory/modules/LcmDisplayDependencies.psm1` | reference | 56, 61 |
| `LCM_Inventory/modules/LcmToolCatalog.psm1` | read+write | 954 |
| `LCM_Inventory/tests/LcmAhkAtoms.Tests.ps1` | read+write | 45 |
| `LCM_Inventory/tests/ToolIntentMetrics.Tests.ps1` | read | 9 |
| `LCM_Inventory/tools/Show-ToolIntents.ps1` | read+write | 3, 7, 59, 530 |
| `LCM_Inventory/tools/Sync-LcmToolCatalogDb.ps1` | reference | 7 |
| `LCM_Inventory/tools/Test-LcmExternalToolDocumentation.ps1` | read | 19, 42, 93, 97 |
| `LCM_Inventory/tools/Test-RepoReadiness.ps1` | read+write | 133 |
| `LCM_Inventory/tools/Update-ToolCatalog.ps1` | read+write | 1413 |
| `LCM_Inventory/tools/sync_tool_catalog_db.py` | read+write | 50 |
