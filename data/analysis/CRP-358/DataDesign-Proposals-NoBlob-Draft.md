# Data Design Draft: Proposal Ledger Without Blobs

Module: data/analysis/CRP-358/DataDesign-Proposals-NoBlob-Draft.md  
Purpose: Column-by-column mapping of the proposal record (proposals.json / proposals.raw_json) to columns, child tables and bundle texts, following the operator decisions of 2026-11-20 (no document blobs; texts in bundle blobs/ with CRP-ID row key; .sql only at push).  
Path: LCM_Inventory/data/analysis/CRP-358/DataDesign-Proposals-NoBlob-Draft.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Draft (CRP-358 proposals step; analysis only, nothing implemented)  
Date: 2026-11-20 21:10:00

---

Basis: `data/proposals/proposals.json` (363 records, 86 columns) and `proposals.db` read 2026-11-20 (read-only). Supersedes section 1.4 of `DataDesign-Proposals-Catalog-Draft.md` (which kept `raw_json`).

## 1. Principles

- Key: `crp_id` (unique, `CRP-nnn` / `BUG-nnn`); `id` stays the numeric key the bundles and cohorts use.
- Scalars become columns of `proposals`; lists and nested objects become child tables keyed by `crp_id` (+ a sequence or sub-key); prose becomes a `.md` file under `docs/Proposals/_blobs/<nnn>_<CRP-ID>/` (frontmatter `CRP-ID`, `column_name`; the row names the file).
- Export rebuilds the document shape the readers expect (as for tools.db); only columns present in a record are emitted (presence is stored, not guessed).
- `raw_json` is kept as a column (never drop) but no longer written or read after the migration.

## 2. Mapping

| Group | Columns | Target |
|:---|:---|:---|
| Identity and lifecycle (existing columns) | id, crp_id, title, origin_repo, state, progress_state, priority, author, lcm_version, bundle_dir, created_at (from `timestamp`), pushed_at, disposition, flow_mode | `proposals` (unchanged) |
| Scalars (new columns) | bundle_id, cr_id, plan_path, walkthrough_path, commit_sha, github_url, app_id, primary_app, always_proceed, origin_major, completed_at, archived_at, archive_run, bcr_disposition, bcr_disposition_at, bcr_initiated_at, bcr_scope, type, regression_needed, cohort_gate_last_outcome, cohort_gate_last_gate, bcr_resolution_receipt, bcr_review_receipt, superseded_at, superseded_by_id, supersedes_id, supersedes_at, reinstatement_revision, description, gate1_accepted, gate1_accepted_at, tier, minimal_tests, test_scope, hold_reason, resume_state, bug_id, bundle_path, specification_path, plan_state, supersedes, superseded_by, bcr_bypass_authorized, bcr_bypass_authorized_at, bcr_bypass_authorized_by, review_receipt, max_regression_depth, severity, successor_crp, original_crp_id, bug_reclassified_at | `proposals` columns (typed; `primary_app` text) |
| Lists | affected_repos, affected_apps, target_subsystems (string or list today) | `proposal_values (crp_id, column_name, seq, value)` |
| Lifecycle dates | dates (state -> timestamp) | `proposal_dates (crp_id, state, at)` |
| State history | state_history (list of {state, timestamp, user, note}; 15 records hold a dict) | `proposal_state_history (crp_id, seq, state, timestamp, user, note)` |
| Document paths | docs, documents (kind -> path) | `proposal_documents (crp_id, source, kind, path)` |
| Small audit objects | bcr_audit, historical_source, review, review_state_repair, specification_acceptance, identity_history (1-27 records each) | `proposal_events (crp_id, event, key, value)`: one row per object column |
| Prose | details (up to 2 000 chars, 11 multi-line), bcr_disposition_notes, reinstatement_changes, state_reason, cm_scope_note, bcr_bypass_reason, bug_reclassification_reason, document_summary | `docs/Proposals/_blobs/<nnn>_<CRP-ID>/<column_name>.md`` |

Top level of proposals.json: settings to `ledger_settings`, `review_cohorts` and `review_obligation_ledger` to their tables, as in `DataDesign-Proposals-Catalog-Draft.md` sections 1.1-1.3; `$schema`, `title`, `updated_at` to `ledger_settings`.

## 3. Text Root (decided 2026-11-20 21:26:32)

All item texts, including those of the 149 records without a bundle, live under `docs/Proposals/_blobs/<nnn>_<CRP-ID>/`.

## 4. Migration Order

1. SQL dump of proposals.db (backup until the completion checks).
2. Create the columns and tables; fill once from proposals.json (with the 117 timestamps of 2026-10-13); write the prose files.
3. Export equals proposals.json for every record (presence and values).
4. Switch `ProposalManager.psm1` (`Get-` / `Set-ProposalStore`) to export / import; then the remaining readers (31 files, `proposals.md` section 5), the Control Hub page, the Go daemon reference.
5. Delete proposals.json and its writers' JSON code; `.sql` only at push; hydrate at pull.

## 5. Table Design (presented 2026-11-20)

```sql
-- proposals: existing table, additive columns only (typed scalars; raw_json kept, no longer written)
ALTER TABLE proposals ADD COLUMN bundle_id TEXT;            -- likewise: cr_id, plan_path, walkthrough_path,
                                                            -- commit_sha, github_url, app_id, primary_app, archive_run,
                                                            -- bcr_disposition, bcr_scope, type, tier, test_scope,
                                                            -- resume_state, bug_id, bundle_path, specification_path,
                                                            -- plan_state, supersedes, superseded_by, severity,
                                                            -- successor_crp, original_crp_id, review_receipt,
                                                            -- cohort_gate_last_outcome, cohort_gate_last_gate,
                                                            -- bcr_resolution_receipt, bcr_review_receipt,
                                                            -- bcr_bypass_authorized_by, description, hold_reason (TEXT)
-- timestamps (TEXT, 'YYYY-MM-DD HH:MM:SS'): completed_at, archived_at, bcr_disposition_at, bcr_initiated_at,
--   superseded_at, supersedes_at, gate1_accepted_at, bcr_bypass_authorized_at, bug_reclassified_at
-- integers: origin_major, superseded_by_id, supersedes_id, reinstatement_revision, max_regression_depth
-- booleans (INTEGER CHECK IN (0,1)): always_proceed, regression_needed, gate1_accepted, minimal_tests,
--   bcr_bypass_authorized

-- columns present in a record with the value null (export emits exactly the keys a record had)
CREATE TABLE proposal_null_columns (
    crp_id TEXT NOT NULL REFERENCES proposals(crp_id),
    column_name  TEXT NOT NULL,
    PRIMARY KEY (crp_id, column_name)
);

-- list columns: affected_repos, affected_apps, target_subsystems (a single string becomes one row)
CREATE TABLE proposal_values (
    crp_id TEXT NOT NULL REFERENCES proposals(crp_id),
    column_name  TEXT NOT NULL CHECK (column_name IN ('affected_repos', 'affected_apps', 'target_subsystems')),
    seq    INTEGER NOT NULL,
    value  TEXT NOT NULL,
    PRIMARY KEY (crp_id, column_name, seq)
);

-- lifecycle dates (record column `dates`: state -> timestamp, order kept)
CREATE TABLE proposal_dates (
    crp_id TEXT NOT NULL REFERENCES proposals(crp_id),
    seq    INTEGER NOT NULL,
    state  TEXT NOT NULL,
    at     TEXT,
    PRIMARY KEY (crp_id, state)
);

-- state history (record column `state_history`)
CREATE TABLE proposal_state_history (
    crp_id    TEXT NOT NULL REFERENCES proposals(crp_id),
    seq       INTEGER NOT NULL,
    state     TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    user      TEXT,
    note      TEXT,            -- one-line note; prose beyond one line goes to blobs/
    PRIMARY KEY (crp_id, seq)
);

-- document paths (record columns `docs` and `documents`)
CREATE TABLE proposal_documents (
    crp_id TEXT NOT NULL REFERENCES proposals(crp_id),
    source TEXT NOT NULL CHECK (source IN ('docs', 'documents')),
    kind   TEXT NOT NULL,      -- specification, plan, walkthrough, implementation_plan, ...
    path   TEXT NOT NULL,
    PRIMARY KEY (crp_id, source, kind)
);

-- small audit objects: bcr_audit, historical_source, review, review_state_repair, specification_acceptance,
-- identity_history (one row per object column)
CREATE TABLE proposal_events (
    crp_id     TEXT NOT NULL REFERENCES proposals(crp_id),
    event      TEXT NOT NULL,
    seq        INTEGER NOT NULL,   -- column order inside the object
    key        TEXT NOT NULL,
    value      TEXT,
    value_kind TEXT NOT NULL CHECK (value_kind IN ('null', 'text', 'bool', 'int', 'real')),
    PRIMARY KEY (crp_id, event, key)
);

-- prose under docs/Proposals/_blobs/<nnn>_<CRP-ID>/ (two-way: the row names the file, the file frontmatter names CRP-ID + column_name)
CREATE TABLE proposal_texts (
    crp_id    TEXT NOT NULL REFERENCES proposals(crp_id),
    column_name     TEXT NOT NULL,       -- details, bcr_disposition_notes, reinstatement_changes, state_reason,
                                   -- cm_scope_note, bcr_bypass_reason, bug_reclassification_reason, document_summary
    file_path TEXT NOT NULL UNIQUE, -- relative to the git root
    PRIMARY KEY (crp_id, column_name)
);

-- ledger settings (top level of proposals.json: review_granularity, lcm_mode, testing_mode, flow_mode,
-- always_proceed, minimal_tests, test_scope, active_context, last_proposal_id, $schema, title, updated_at,
-- review_obligation_ledger.version)
CREATE TABLE ledger_settings (
    key        TEXT PRIMARY KEY,
    value      TEXT,
    value_kind TEXT NOT NULL CHECK (value_kind IN ('null', 'text', 'bool', 'int', 'real')),
    updated_at TEXT NOT NULL
);

-- review cohorts
CREATE TABLE review_cohorts (
    cohort_id         TEXT PRIMARY KEY,                 -- COH-<prime>
    prime_proposal_id INTEGER NOT NULL REFERENCES proposals(id),
    state             TEXT NOT NULL CHECK (state IN ('open', 'held', 'closed')),
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL,
    closed_at         TEXT
);
CREATE UNIQUE INDEX idx_one_open_cohort ON review_cohorts(state) WHERE state = 'open';
CREATE TABLE review_cohort_members (
    cohort_id   TEXT NOT NULL REFERENCES review_cohorts(cohort_id),
    seq         INTEGER NOT NULL,
    proposal_id INTEGER NOT NULL REFERENCES proposals(id),
    PRIMARY KEY (cohort_id, proposal_id)
);
CREATE TABLE review_cohort_repositories (
    cohort_id  TEXT NOT NULL REFERENCES review_cohorts(cohort_id),
    seq        INTEGER NOT NULL,
    repository TEXT NOT NULL,
    PRIMARY KEY (cohort_id, repository)
);
CREATE TABLE review_cohort_gates (                      -- gate_history
    cohort_id      TEXT NOT NULL REFERENCES review_cohorts(cohort_id),
    gate_seq       INTEGER NOT NULL,
    gate           TEXT NOT NULL,
    required_state TEXT,
    timestamp      TEXT NOT NULL,
    PRIMARY KEY (cohort_id, gate_seq)
);
CREATE TABLE review_cohort_gate_members (               -- member lists of a gate entry
    cohort_id   TEXT NOT NULL,
    gate_seq    INTEGER NOT NULL,
    list        TEXT NOT NULL CHECK (list IN ('synchronized', 'no_op', 'stopped')),
    seq         INTEGER NOT NULL,
    proposal_id INTEGER,
    detail      TEXT,                                   -- stop reason of a stopped member
    PRIMARY KEY (cohort_id, gate_seq, list, seq),
    FOREIGN KEY (cohort_id, gate_seq) REFERENCES review_cohort_gates(cohort_id, gate_seq)
);
CREATE TABLE review_cohort_audit (                      -- completion_audit (one row per column)
    cohort_id  TEXT NOT NULL REFERENCES review_cohorts(cohort_id),
    seq        INTEGER NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT,
    value_kind TEXT NOT NULL CHECK (value_kind IN ('null', 'text', 'bool', 'int', 'real')),
    PRIMARY KEY (cohort_id, key)
);

-- review obligations (review_obligation_ledger.entries)
CREATE TABLE review_obligations (
    obligation_id    TEXT PRIMARY KEY,                  -- <item>::<repository>
    proposal_id      INTEGER NOT NULL REFERENCES proposals(id),
    repository       TEXT NOT NULL,
    status           TEXT NOT NULL,
    reason           TEXT NOT NULL,
    bcr_identity     TEXT NOT NULL,
    discovered_at    TEXT NOT NULL,
    completed_at     TEXT,
    last_observed_at TEXT,
    review_receipt   TEXT,
    commit_sha       TEXT,
    resolution_note  TEXT,
    UNIQUE (proposal_id, repository)
);
CREATE TABLE review_obligation_reasons (                -- observed_reasons
    obligation_id TEXT NOT NULL REFERENCES review_obligations(obligation_id),
    seq           INTEGER NOT NULL,
    reason        TEXT NOT NULL,
    PRIMARY KEY (obligation_id, seq)
);
```

Views (for displays and joins): `v_proposals` (record with lists aggregated), `v_proposal_texts` (row -> file),
`v_open_cohort`, `v_open_obligations`.
