# CRP-358 Reconciliation: strategies.json

Module: data/analysis/CRP-358/strategies.md  
Purpose: CRP-358 Reconciliation: strategies.json  
Path: LCM_Inventory/data/analysis/CRP-358/strategies.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (CRP-358 phase 1, read-only)  
Date: 2026-11-19 17:22:28

---

Method: databases opened read-only (`mode=ro`); JSON files read only; nothing was changed. Reader/writer classification is a file-level heuristic (write / read operations present in a file that names the store); a path that is passed to another module is listed as "reference".

## 1. Store

- JSON: `LCM_Inventory/data/proposals/strategies.json`
- Table(s): proposals.db: strategies, strategy_crps

## 2. Key Sets

| JSON keys | Table keys | Both | Only JSON | Only table |
|---:|---:|---:|---:|---:|
| 4 | 4 | 4 | 0 | 0 |

## 3. Field Differences (common keys; the table wins in a dispute, operator 2026-11-19)

None.

## 4. Data Without A Column

None.

## 5. Readers And Writers (2 files, 3 lines)

| File | Class (file level) | Lines |
|:---|:---|:---|
| `LCM_Inventory/tools/Show-Strategies.ps1` | read+write | 6, 40 |
| `LCM_Inventory/tools/sync_proposals_db.py` | read+write | 444 |
