# Walkthrough: CRP-358 - Retire JSON Stores Replaced By SQLite

Status: In Progress
Date: 2026-11-18 15:41:02

## Tools step (2026-11-20 17:32:48)

- Backup before the schema change: `scratch/CRP-358/tools-before-crp358.db` plus both JSON files (SQL dump rule).
- Migration (table wins for statistics): 331 tools, 683 intents; export equals both JSON documents (catalog identical; intents identical outside the statistics).
- Issue on the way: the first generator run read the catalog as one item (`return , @(...)` in the accessor), so no metadata was inherited (Admin levels, short names, trampolines changed). Fixed; store restored by `migrate` from the JSON baseline; the next run matched the JSON exactly except the real new dependency of Update-ToolCatalog on LcmToolCatalog.psm1. The bad run left no launcher changes (`Cmd/` unchanged).
- Evidence: parse gate 28 files clean (two class files only report types defined elsewhere, RULE-PS-020); `py_compile` + flake8 clean; `Sync-LcmToolCatalogDb.ps1 -Action Verify` all PASS (331 tools, 683 intents, 330 atoms, 0 conflicts); Pester: ToolIntentMetrics, ToolPermissionLevels, Sync-LcmCatalogMacros, LcmElevatedDaemon, LcmAhkAtoms, MacriumBcrReview, MacriumBaselineAtoms, ToolExplorerVersion, LcmRuntimeAtoms, Test-LcmPushRequalification, LcmDisplayVersion, LcmDisplayFreshness, InvokeLcmDisplayRender all green; ControlHubSafety 1 failure that predates this run (see CRP-382).
- Live: ShowToolIntents rendered from tools.db; Test-LcmExternalToolDocumentation 39 executables, 0 undocumented; elevation policy re-exported (current catalog data).
- A search finds no code reading `config/tool_catalog.json` / `config/tool_intents.json` (remaining hits: generated `data/dependencies/forward-index.json`, `proposals.json` text, historical bundle references).

## Reads never write (2026-11-20 17:39:43, operator choice A after the SQLite search/locking review)

- Defect of this CRP's engine found in the review: every read (export, verify) ran the schema setup (metadata row, `v_atoms` recreated, runtime seed rows) and so took a write lock. Fixed in `sync_tool_catalog_db.py` 10.2.8: reads open `mode=ro`, record-call skips the schema setup, explicit `busy_timeout` 5000 ms.

## Gate 2 changes (2026-11-20 20:48:28)

- `raw_json` / `aliases_json` removed (added within this CRP, never committed); the lists are child tables `tool_aliases` (24 rows), `tool_parameters` (878), `tool_dependencies` (547), `intent_parameters` (1976); the legacy JSON-text columns `parameters_json`, `dependencies_json`, `tool_intents.parameters` are kept (never drop) but no longer written. Backup before the restructure: `scratch/CRP-358/tools-before-noblob.db` and `.sql`.
- Export rebuilds the retired document shape from columns: migration from the retained JSON copies is exact (331 tools, 683 intents, key order equal, 0 field differences; single-string `Aliases` / `Dependencies` become one-element lists). The following generator run differs only in 12 real `Dependencies` (tools that now import `LcmToolCatalog.psm1`).
- `.sql` only at publish: import / sync / migrate no longer dump; `Invoke-LCM_Push.ps1` step 2a writes `tools.sql` and commits it with the ledger projections; `tools.sql` reset to its committed state (it had been rewritten outside a publish earlier today).
- Pull: new action `restore` (`tools.sql` -> fresh database, checked, atomic replace, previous file kept as `tools.db.before-restore`); `post-checkout` and `post-merge` run it when `tools.sql` changed. Round trip dump -> restore: all 12 tables and the views identical.
- Note: the existing hooks call bare `python` (RULE-PY-010 asks for the registered interpreter); kept as found, same line style.
- Side observation: `git restore` of `tools.sql` ran the existing proposals hydrate hook; ledger states checked afterwards, unchanged.
- Test evidence (final engine): parse gate clean; 14 test files 152 passed; ProposalLifecycle fails 3 cases only when run in one Pester session together with other files, 50/50 alone (ordering dependency between test files, test isolation as BUG-375 / CRP-373, not caused by this step).

## Strategies step (2026-11-20 21:02:19)

- `data/proposals/strategies.json` deleted (copy in `scratch/CRP-358/`); the tables `strategies` / `strategy_crps` are the only store; `sync_proposals_db.py` 10.2.4 no longer syncs from the JSON.
- New read-only actions: `export-strategies` (former document shape; equal to the JSON before deletion) and `check-strategies` (the former inline Python of `Test-LcmStrategyConsistency.ps1`, CRP-366 open item closed).
- Found on the way: `hydrate` rebuilt only `proposals.sql` at pull, `strategies.sql` was written at push but never read back; `hydrate` now also runs `strategies.sql` (test: emptied strategy tables on a copy -> 4 strategies, 10 links restored).
- Found on the way: `install-hooks` regenerated `post-merge` / `post-checkout` from a template without the `tools.db` rebuild; the template now carries it (generated hook equals the live hook).
- Evidence: `py_compile` + flake8 clean, parse gate clean; ShowStrategies rendered (4 strategies); `Test-LcmStrategyConsistency.ps1` PASS (4 strategies, 10 mappings); `docs/DataDesign-Proposals.md` 10.2.4 section 2.3.
- Next: the `proposals.json` step (largest: ProposalManager.psm1 and about 31 files; tables per `data/analysis/CRP-358/DataDesign-Proposals-Catalog-Draft.md`, texts in bundle `blobs/` with CRP-ID row key, the 117 JSON timestamps, `.sql` only at push).
- Operator (2026-11-20 21:03:04): the two fixes found on the way (hydrate reads strategies.sql back; install-hooks keeps the tools.db rebuild) are accepted as immediate needs within this CRP; no separate CRP or BUG.

## Restructuring backups (2026-11-20 22:13:42, operator choice A)

- Wording: "SQL dump before restructuring" is now a **restructuring backup** (git-ignored `scratch/db-backups/`, never committed, deleted by `COMPLETE`), kept apart from the publish projections (`.sql` only at push / pull); Specification invariant and Storage Rules 1 updated.
- New atom `tools/lcm_db_backup.py`: dry run of the schema setup on an in-memory schema copy; a full SQL backup only when the schema would change; a failed backup stops the change; `--purge` / `--list` / `--backup`.
- Wired into `sync_tool_catalog_db.py` 10.2.10 (`open_store`; `restore` backs up first) and `sync_proposals_db.py` (sync schema setup; `hydrate` backs up an existing database first); `Complete-Review.ps1` 10.7.6 purges after a successful completion (not when a test injects `-SubmitScriptPath`).
- Evidence (isolated copies): unchanged schema -> no backup; dropped `tools.role` -> 1 backup (schema + 331 tool rows), column restored; reads -> no backup; ledger sync unchanged -> no backup; hydrate -> 1 backup; purge removed both test backups. Gates clean (py_compile, flake8, parser); Pester 69 passed (ProposalLifecycle included, green in the joint run this time); store verify PASS.
