# Data Design Draft: Proposal Settings, Review Cohorts, Review Obligations, Catalog Fields

Module: data/analysis/CRP-358/DataDesign-Proposals-Catalog-Draft.md  
Purpose: Draft tables and columns that must exist before proposals.json and tool_catalog.json can be retired (CRP-358).  
Path: LCM_Inventory/data/analysis/CRP-358/DataDesign-Proposals-Catalog-Draft.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Draft (CRP-358 analysis, operator answer 2026-11-19 (2); nothing implemented)  
Date: 2026-11-19 17:30:38

---

Basis: proposals.json, tool_catalog.json and both databases read on 2026-11-19 17:30:38 (databases with `mode=ro`); the
reconciliation in this folder. Rule constraints: no field is dropped (archive by marking), an SQL dump precedes each
restructuring, the committed `.sql` projections carry every new table.

## 1. proposals.db

### 1.1 Table `ledger_settings` (new; replaces the top-level settings of proposals.json)

| Column | Type | Constraint |
|:---|:---|:---|
| `key` | TEXT | PRIMARY KEY |
| `value_json` | TEXT | NOT NULL (JSON-encoded value: string, number, boolean or null) |
| `updated_at` | TEXT | NOT NULL |

Rows at migration (current values):

| Key | Value |
|:---|:---|
| `review_granularity` | `"tight"` |
| `lcm_mode` | `"active"` |
| `last_proposal_id` | `375` |
| `testing_mode` | `"active"` |
| `active_context` | `null` |
| `flow_mode` | `"standard"` |
| `always_proceed` | `false` |
| `minimal_tests` | `false` |
| `test_scope` | `"full"` |

`last_proposal_id` becomes a check value only: the next id is `MAX(proposals.id) + 1`, guarded by the PRIMARY KEY; the
setting is kept for readers until they are switched. `_lcm_db_metadata` stays for sync bookkeeping (hydrated_at,
schema_version, lcm_version, workspace_role, sandbox_id); its `workspace_root` holds an absolute drive path (CRP-371).

### 1.2 Tables `review_cohorts`, `review_cohort_members`, `review_cohort_gates` (new)

Current data: 9 cohorts, all `closed`; fields per cohort: `id`, `state`, `prime_proposal_id`, `proposal_ids`, `repositories`, `created_at`, `gate_history`, `updated_at`, `closed_at`, `completion_audit`.

`review_cohorts`

| Column | Type | Constraint |
|:---|:---|:---|
| `cohort_id` | TEXT | PRIMARY KEY (`COH-<prime>`) |
| `prime_proposal_id` | INTEGER | NOT NULL, FK `proposals.id` |
| `state` | TEXT | NOT NULL CHECK (state IN ('open','held','closed')); a partial UNIQUE index allows one `open` row |
| `created_at`, `updated_at` | TEXT | NOT NULL |
| `closed_at` | TEXT | NULL |
| `completion_audit_json` | TEXT | NULL (the completion audit object, kept whole) |

`review_cohort_members (cohort_id FK, proposal_id FK proposals.id, PRIMARY KEY (cohort_id, proposal_id))` from
`proposal_ids`; `review_cohort_repositories (cohort_id FK, repository TEXT, PRIMARY KEY (cohort_id, repository))` from
`repositories`.

`review_cohort_gates`: one row per `gate_history` entry (6 fields):
`gate_seq INTEGER` (order), `cohort_id FK`, `gate TEXT`, `required_state TEXT`, `timestamp TEXT`, and the member lists
`synchronized_member_ids_json`, `no_op_member_ids_json`, `stopped_members_json` (JSON arrays; they are audit records,
not queried relationally); PRIMARY KEY (cohort_id, gate_seq).

### 1.3 Table `review_obligations` (new; replaces review_obligation_ledger)

Current data: version 1, 24 entries; fields: `id`, `repository`, `status`, `discovered_at`, `reason`, `bcr_identity`, `proposal_id`, `completed_at`, `review_receipt`, `commit_sha`, `observed_reasons`, `last_observed_at`, `resolution_note`.

| Column | Type | Constraint |
|:---|:---|:---|
| `obligation_id` | TEXT | PRIMARY KEY (`<item>::<repository>`) |
| `proposal_id` | INTEGER | NOT NULL, FK `proposals.id` |
| `repository` | TEXT | NOT NULL |
| `status` | TEXT | NOT NULL |
| `reason` | TEXT | NOT NULL |
| `bcr_identity` | TEXT | NOT NULL |
| `discovered_at` | TEXT | NOT NULL |
| `completed_at`, `last_observed_at` | TEXT | NULL |
| `review_receipt`, `commit_sha`, `resolution_note` | TEXT | NULL |
| `observed_reasons_json` | TEXT | NULL (JSON array) |

UNIQUE (proposal_id, repository). The ledger `version` moves to `ledger_settings` (`review_obligation_ledger.version`).

### 1.4 Table `proposals` (existing; additive only)

- `raw_json` keeps the complete record (identical for 348 of 348 rows today); the 67 row fields without a column stay
  in it. Promoting a field to a column is a separate decision per field (none required for the retirement).
- 2026-10-13 timestamps (operator 2026-11-19, exception to "table wins", these values only): for the 88 `pushed_at`
  and 29 `created_at` values that differ, the JSON value (`pushed_at`, `timestamp`) is written into the column; the
  migration report lists the 117 (id, column, old value, new value) tuples; `raw_json` is already equal to the JSON.
- `flow_mode`: the 213 NULLs of the JSON are written as the column value `standard` (table default; no dispute).

## 2. tools.db: catalog fields without a column

Current data (tool_catalog.json, 331 tools):

| Field | Values today | Proposed column / table |
|:---|:---|:---|
| `Aliases` | NoneType: 314, list: 5, str: 12 (string in 12 rows, list in 5) | table `tool_aliases (tool_id FK tools.id, alias TEXT, PRIMARY KEY (tool_id, alias))`; `alias` UNIQUE across tools (collision check of the generator); a string value becomes one alias |
| `Role` | Utility 268, Customization 25, GUI 7, Diagnostics 7, Invariants 5, Recovery 3 ... (16 values) | column `tools.role TEXT` |
| `Domain` | LCM_Inventory 147, SystemConfiguration 77, LCM_Tools 74, HaSSD06 20, HaSSD06_Inventory 8, LCM_Supervision 4, LCM 1 | column `tools.domain TEXT` (owning repository; `tools.subsystem` stays as is) |
| `IntentElevated` | None: 329, False: 1, True: 1 | not a tools column: it is the atom elevation and moves to `atoms.elevated` (CRP-363 design) |

## 3. Migration (per store, in the CRP-358 order)

1. SQL dump of the database (`.sql` backup kept until the completion checks).
2. Create the new tables (additive DDL, `CREATE TABLE IF NOT EXISTS`), owned by the database: the JSON-to-table sync
   never empties them.
3. Fill them once from the JSON (proposals: settings, cohorts, obligations, the 117 timestamps; catalog: aliases, role,
   domain; IntentElevated via the atoms table); write a migration report under data/analysis/CRP-358/.
4. Switch every writer, then every reader to the tables (inventory in the per-store reports, section 5).
5. Verify (reconciliation re-run shows zero differences), then delete the JSON file and its writers' JSON code in the
   same change set.

## 4. Open Questions

- None for this draft beyond the CRP-363 required-switch field (affects `atoms`, not these tables).
