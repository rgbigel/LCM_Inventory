# CRP-358 Reconciliation Summary

Module: data/analysis/CRP-358/Summary.md  
Purpose: CRP-358 Reconciliation Summary  
Path: LCM_Inventory/data/analysis/CRP-358/Summary.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (CRP-358 phase 1, read-only)  
Date: 2026-11-19 17:22:28

---

Method: databases opened read-only (`mode=ro`); JSON files read only; nothing was changed. Reader/writer classification is a file-level heuristic (write / read operations present in a file that names the store); a path that is passed to another module is listed as "reference".

| Store | JSON | Table | Only JSON | Only table | Differing fields (rows) | Data without column | Code files |
|:---|---:|---:|---:|---:|:---|:---|---:|
| `strategies.json` | 4 | 4 | 0 | 0 | none | none | 2 |
| `proposals.json` | 348 | 348 | 0 | 0 | flow_mode (213), pushed_at (88), created_at<-timestamp (29) | 71 row fields (in raw_json) + settings, cohorts, obligations | 31 |
| `tool_catalog.json` | 331 | 331 | 0 | 0 | none | Aliases, Role, Domain, IntentElevated | 23 |
| `tool_intents.json` | 683 | 683 | 0 | 0 | call_count (7), last_called_at (7) | none | 11 |

## Findings

1. Key sets agree for all four stores (no key only on one side).
2. `proposals`: `flow_mode` is null in JSON and the column default `standard` in the table (213 rows): a default, no
   dispute. `pushed_at` (88 rows) and `created_at` vs `timestamp` (29 rows) differ for items of 2026-10-13: the JSON
   holds batch times (e.g. 23:09:10 / 23:17:33), the table holds earlier individual times. This overlaps the open
   operator decision of CRP-355 (re-stamped legacy ids >= 100).
3. `proposals`: settings (`review_granularity`, `lcm_mode`, `testing_mode`, `flow_mode`, `always_proceed`,
   `minimal_tests`, `test_scope`, `active_context`, `last_proposal_id`), `review_cohorts` and
   `review_obligation_ledger` have no table: schema additions are needed before the JSON can go.
4. `tool_catalog`: `Aliases`, `Role`, `Domain`, `IntentElevated` (all 331 rows) have no column: schema additions needed.
5. `tool_intents`: the JSON carries newer call statistics than the table (`call_count`, `last_called_at`, 7 rows): a
   writer updates the statistics in the JSON between syncs.
6. `strategies`: identical.
