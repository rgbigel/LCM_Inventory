# CRP-358 Reconciliation: proposals.json

Module: data/analysis/CRP-358/proposals.md  
Purpose: CRP-358 Reconciliation: proposals.json  
Path: LCM_Inventory/data/analysis/CRP-358/proposals.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (CRP-358 phase 1, read-only)  
Date: 2026-11-19 17:22:28

---

Method: databases opened read-only (`mode=ro`); JSON files read only; nothing was changed. Reader/writer classification is a file-level heuristic (write / read operations present in a file that names the store); a path that is passed to another module is listed as "reference".

## 1. Store

- JSON: `LCM_Inventory/data/proposals/proposals.json`
- Table(s): proposals.db: proposals, _lcm_db_metadata

## 2. Key Sets

| JSON keys | Table keys | Both | Only JSON | Only table |
|---:|---:|---:|---:|---:|
| 348 | 348 | 348 | 0 | 0 |

## 3. Field Differences (common keys; the table wins in a dispute, operator 2026-11-19)

| Field | Rows | Examples (key: JSON / table) |
|:---|---:|:---|
| `flow_mode` | 213 | 1: `` / `standard`; 10: `` / `standard`; 100: `` / `standard` |
| `pushed_at` | 88 | 100: `2026-10-13 23:17:33` / `2026-10-13 15:53:01`; 101: `2026-10-13 23:17:33` / `2026-10-13 15:53:01`; 102: `2026-10-13 23:17:33` / `2026-10-13 15:53:01` |
| `created_at<-timestamp` | 29 | 100: `2026-10-13 23:09:10` / `2026-10-13 17:30:00`; 101: `2026-10-13 23:09:10` / `2026-10-13 18:00:00`; 102: `2026-10-13 23:09:10` / `2026-10-13 18:30:00` |

## 4. Data Without A Column

- Row fields without a column: 71 fields; all preserved in `raw_json` (`raw_json` equals the JSON row for 348 of 348 rows).
- Top-level data without a table: `$schema`, `title`, `updated_at`, `review_granularity`, `lcm_mode`, `last_proposal_id`, `testing_mode`, `active_context`, `review_cohorts`, `review_obligation_ledger`, `flow_mode`, `always_proceed`, `minimal_tests`, `test_scope`.
- Sizes: review_cohorts 9, review_obligation_ledger entries 24.
- `_lcm_db_metadata` keys: `hydrated_at`, `last_synced_at`, `lcm_version`, `sandbox_id`, `schema_version`, `workspace_role`, `workspace_root`.

## 5. Readers And Writers (31 files, 46 lines)

| File | Class (file level) | Lines |
|:---|:---|:---|
| `LCM_Inventory/assets/CM_CONTROL_HUB.html` | read+write | 3092 |
| `LCM_Inventory/modules/LcmDisplayDependencies.psm1` | reference | 46, 51 |
| `LCM_Inventory/modules/ProposalManager.psm1` | read+write | 81 |
| `LCM_Inventory/src/do/daemon.go` | reference | 108, 628 |
| `LCM_Inventory/tests/ControlHubSafety.Tests.ps1` | read+write | 248 |
| `LCM_Inventory/tests/FailureModeAnalysis.Tests.ps1` | read+write | 206, 212, 284 |
| `LCM_Inventory/tests/Fix-Documentation.Tests.ps1` | read+write | 6 |
| `LCM_Inventory/tests/LCM_SwitchIntegration.Tests.ps1` | read+write | 4 |
| `LCM_Inventory/tests/LcmMajorCleanup.Tests.ps1` | read+write | 51 |
| `LCM_Inventory/tests/ProposalCompletion.Tests.ps1` | read+write | 39, 48 |
| `LCM_Inventory/tests/ProposalManager.Tests.ps1` | read+write | 14, 16 |
| `LCM_Inventory/tests/ProposalScaffold.Tests.ps1` | read+write | 23 |
| `LCM_Inventory/tests/ProposalSpecificationState.Tests.ps1` | read+write | 19 |
| `LCM_Inventory/tests/ProposalStoreFieldGuard.Tests.ps1` | read+write | 17 |
| `LCM_Inventory/tests/Test-LcmProposalsDb.Tests.ps1` | read | 10, 41 |
| `LCM_Inventory/tests/Test-LcmPushRequalification.Tests.ps1` | write | 49 |
| `LCM_Inventory/tools/Absorb-LcmContextRemark.ps1` | read+write | 92 |
| `LCM_Inventory/tools/Fix-Documentation.ps1` | read+write | 182 |
| `LCM_Inventory/tools/Invoke-LCM_Push.ps1` | read+write | 86, 429 |
| `LCM_Inventory/tools/Invoke-LcmMajorCleanup.ps1` | read+write | 213 |
| `LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1` | read | 47 |
| `LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1` | read+write | 349 |
| `LCM_Inventory/tools/LcmDesktopDaemon.ps1` | read+write | 411, 412, 456 |
| `LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1` | read+write | 101 |
| `LCM_Inventory/tools/Publish-LCM_ProposalBundles.ps1` | reference | 66, 94, 108 |
| `LCM_Inventory/tools/Show-LcmControl.ps1` | read+write | 198 |
| `LCM_Inventory/tools/Show-Strategies.ps1` | read+write | 41 |
| `LCM_Inventory/tools/Submit-ReviewResult.ps1` | read+write | 277 |
| `LCM_Inventory/tools/Sync-GeminiInbox.ps1` | reference | 8 |
| `LCM_Inventory/tools/Sync-LcmProposalsDb.ps1` | read | 49, 62, 66, 134 |
| `LCM_Inventory/tools/sync_proposals_db.py` | read+write | 31 |
