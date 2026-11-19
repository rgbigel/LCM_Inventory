# CRP-358 Reconciliation: tool_catalog.json

Module: data/analysis/CRP-358/tool_catalog.md  
Purpose: CRP-358 Reconciliation: tool_catalog.json  
Path: LCM_Inventory/data/analysis/CRP-358/tool_catalog.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (CRP-358 phase 1, read-only)  
Date: 2026-11-19 17:22:28

---

Method: databases opened read-only (`mode=ro`); JSON files read only; nothing was changed. Reader/writer classification is a file-level heuristic (write / read operations present in a file that names the store); a path that is passed to another module is listed as "reference".

## 1. Store

- JSON: `LCM_Inventory/config/tool_catalog.json`
- Table(s): tools.db: tools, tool_atom_permissions

## 2. Key Sets

| JSON keys | Table keys | Both | Only JSON | Only table |
|---:|---:|---:|---:|---:|
| 331 | 331 | 331 | 0 | 0 |

## 3. Field Differences (common keys; the table wins in a dispute, operator 2026-11-19)

None.

## 4. Data Without A Column

| Field | Rows |
|:---|---:|
| `Aliases` | 331 |
| `Role` | 331 |
| `Domain` | 331 |
| `IntentElevated` | 331 |

- `AllowedAtoms` vs `tool_atom_permissions`: JSON 6, table 6, only JSON 0, only table 0.

## 5. Readers And Writers (23 files, 49 lines)

| File | Class (file level) | Lines |
|:---|:---|:---|
| `LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1` | read+write | 438, 868, 965 |
| `LCM_Inventory/modules/LcmDaemon/Classes/LcmSecurityGateway.ps1` | read | 55 |
| `LCM_Inventory/modules/LcmDisplayDependencies.psm1` | reference | 31, 46, 56, 61, 103 |
| `LCM_Inventory/modules/LcmToolCatalog.psm1` | read+write | 31, 32, 833 |
| `LCM_Inventory/tests/Sync-LcmCatalogMacros.Tests.ps1` | read+write | 61 |
| `LCM_Inventory/tests/ToolPermissionLevels.Tests.ps1` | read+write | 69 |
| `LCM_Inventory/tools/Create-LcmTool.ps1` | write | 13 |
| `LCM_Inventory/tools/Export-LCMRules.ps1` | read+write | 342, 344 |
| `LCM_Inventory/tools/Invoke-LCM_Maintenance.ps1` | read | 206 |
| `LCM_Inventory/tools/Invoke-LCM_Push.ps1` | read+write | 276, 277 |
| `LCM_Inventory/tools/Invoke-LcmAction.ps1` | read | 145 |
| `LCM_Inventory/tools/Invoke-LcmProtocol.ps1` | read+write | 92 |
| `LCM_Inventory/tools/Invoke-PrivilegedTool.ps1` | read | 7, 106, 107, 249 |
| `LCM_Inventory/tools/LcmDesktopDaemon.ps1` | read+write | 617, 651 |
| `LCM_Inventory/tools/Remove-LcmShortName.ps1` | read+write | 211 |
| `LCM_Inventory/tools/Show-ToolIntents.ps1` | read+write | 530 |
| `LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1` | read+write | 6, 15, 94, 109, 126, 269 |
| `LCM_Inventory/tools/Sync-LcmToolCatalogDb.ps1` | reference | 7 |
| `LCM_Inventory/tools/Sync-ToolSymlinks.ps1` | read | 6, 54, 144, 155 |
| `LCM_Inventory/tools/Test-GeneralReadiness.ps1` | read | 184, 186, 220 |
| `LCM_Inventory/tools/Test-RepoReadiness.ps1` | read+write | 133 |
| `LCM_Inventory/tools/Update-ToolCatalog.ps1` | read+write | 7, 63, 152 |
| `LCM_Inventory/tools/sync_tool_catalog_db.py` | read+write | 49 |
