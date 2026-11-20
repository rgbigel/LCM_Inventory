# Specification: CRP-358

Module: docs/Proposals/358_CRP-Retire-JSON-Stores-Replaced-By-SQLite/Specification CRP-358.md  
Purpose: Retire JSON Stores Replaced By SQLite  
Path: LCM_Inventory/docs/Proposals/358_CRP-Retire-JSON-Stores-Replaced-By-SQLite/Specification CRP-358.md  
Authors: Rolf  
Version: 10.7.4  
Status: In Review  
Date: 2026-11-20 22:12:42

```yaml
CRP-ID: CRP-358
Title: Retire JSON Stores Replaced By SQLite
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:41:02
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic C): JSON is the authority in practice although RULE-LCM-001 names proposals.db. Retire in order: strategies.json, tool_intents.json, tool_catalog.json, proposals.json (last; cohorts, obligations and settings are missing in the DB). Each step: read-only reconciliation report (key sets, field comparison, settings) under data/analysis, operator decision, schema additions, store accessor switched to SQLite, JSON deleted in the same change set as its writers.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
T1 The SQLite tables are the only store: proposals.db for the ledger and strategies, tools.db for tools, intents and atom permissions; the catalog generator and every other writer write the tables directly.

T2 One-time reconciliation per JSON file against its table; in a dispute the table wins (operator 2026-11-19).

T3 After the reconciliation no tool reads or writes the JSON file again, and it is physically deleted in the same change set as its last reader and writer ("as soon as possible", operator 2026-11-19).

### Invariants and Exit Criteria
- No ledger or table column is dropped (archive by marking); a restructuring backup is taken before any table restructuring (see Storage Rules 1).
- Every switched reader and writer passes its syntax gate and tests; the reconciliation report per file is kept under data/analysis.
- Exit: none of the four JSON files exists; a search finds no code reading or writing them.

### Explicit Non-Goals
- Generated presentation artifacts that merely embed data (displays); they move to live data with CRP-382.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

### Dependents
- CRP-361 T4 (intent call statistics), CRP-363 (atom data design), CRP-369 (planned together).

## Absorbed Operator Remarks

> another problem resulted from using the old version of SQLite tables which were represented as .json files. As per a previous CRP, i had already asked to to a one - time match, giving preference to the tables in case of "dispute", AND THEN NEVER TO USE THE .json FILES AGAIN. They should be eliminated physically as soon as possible.

(Operator, 2026-11-19.)

## Operator Decisions (2026-11-19 17:29:38)

1. Old timestamps (2026-10-13 items): for `pushed_at` (88 rows) and `created_at` (29 rows) the JSON batch times win; the
   table is corrected to the JSON values before `proposals.json` is deleted (exception to "the table wins", these
   117 values only).
2. Missing tables: draft the data design for proposal settings, review cohorts, review obligations and the catalog fields
   `Aliases`, `Role`, `Domain`, `IntentElevated` (read-only draft under `data/analysis/CRP-358/`).
3. Intent call statistics: the writer `Update-LcmToolIntentCall` (`modules/LcmToolCatalog.psm1`) moves to the table with
   the tool stores; tests writing into the live store are BUG-375.

## Operator Decision (2026-11-20 00:34:22)

- "We must eliminate all" JSON stores: also `data/tools/elevation_policy.json` (generated from tools.db for the Go daemon, which has no SQLite driver); it goes when the daemon reads SQLite itself (CRP-382 driver decision).
- Verified write direction (2026-11-20): JSON first, table copied from it - `Set-ProposalStore` writes proposals.json and syncs JSON to proposals.db; `Update-ToolCatalog.ps1` writes tool_catalog.json / tool_intents.json and `sync_tool_catalog_db.py` copies them into tools.db. CRP-358 reverses this: writers write the tables, the JSON files are deleted.

## Absorbed From BUG-348 (2026-11-20 17:18:34)

- BUG-348 item 1: the Go daemon lacks the routes `/set_priority` and `/query_all_short_names` (and `/print`, `/abort`) that pages call; the legacy PowerShell daemon served them from `proposals.json` / `tool_catalog.json`. Decision 2026-11-19: served through the governed tools and the tables, implemented with this CRP (no new JSON dependency).

## Operator Decisions 2026-11-20: Storage Rules (consolidated 2026-11-20 21:40:30)

Consolidated by operator instruction from the decision entries of 2026-11-20 (17:39, 20:48, 20:52, 20:55, 20:59, 21:26, 21:35); superseded intermediate locations are left out, the earlier wording is in the Git history.

### 1. SQL projections

- `.sql` files are publish projections only: they exist so a pushed state can be rebuilt from the remote. They are written at push (`Invoke-LCM_Push.ps1` step 2a) and rebuilt into the tables at pull (git hooks `post-checkout` / `post-merge`: `sync_proposals_db.py --action hydrate`, `sync_tool_catalog_db.py --action restore`); no other use.
- An earlier open item to write `proposals.sql` on every ledger write (for text search) is withdrawn; text search goes through the text files of section 3.
- Restructuring backups are a different thing (operator 2026-11-20): before any schema change and before a rebuild at pull, the store engine writes a full SQL backup to the git-ignored `scratch/db-backups/` (`tools/lcm_db_backup.py`; a failed backup stops the change); never committed; deleted by `COMPLETE` after a successful completion.

### 2. No blobs in the tables

- Tables hold scalar columns and child tables only; no document or JSON blobs.
- Text lives in normal `.md` files (or small `.json` objects), linked both ways with its table row (row -> file path; file frontmatter -> row key), so textual lookup works on the files (Obsidian may be considered).

### 3. Text storage

- Texts of CRP/BUG items: one shared root next to the bundles, `docs/Proposals/_blobs/<nnn>_<CRP-ID>/<column_name>.md` (e.g. `docs/Proposals/_blobs/358_CRP-358/details.md`). No slug in the path, so renames never move files; the title is in the frontmatter.
- Texts of tables not tied to an item (e.g. the tool store): `docs/DataDesign-<Domain>/blobs/`, next to the table's data design document.
- Row key: the frontmatter names `CRP-ID` and `column_name`; tables with several rows per item add secondary key(s) (e.g. repository, cohort member). The combination `CRP-ID` + secondary key(s) + `column_name` is unique (normalized, usable as a join key in views). The table row names the file.
- The `_` prefix sorts the root apart from the `<nnn>_...` bundle folders and keeps every bundle scan (resolver, purge, displays: names starting with a digit) from treating it as a bundle.
- Both locations are under `docs/`: visible, never git-ignored (checked 2026-11-20), and part of the visual review.
- Consequences: the bundle purge at push never touches item texts (no CRP-339 exception needed); the 149 records without a bundle keep their texts in the same root.

### 4. Ledger data design

- The blob-free ledger design is accepted: `docs/DataDesign-Proposals.md` section 2.4 and `data/analysis/CRP-358/DataDesign-Proposals-NoBlob-Draft.md` section 5 (columns named `column_name`). Implementation follows the migration order of the draft, section 4.
