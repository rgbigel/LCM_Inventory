# Implementation Plan: CRP-358 - Retire JSON Stores Replaced By SQLite

Status: In Progress
Date: 2026-11-18 15:41:02

## Step: tool_intents.json + tool_catalog.json (with CRP-363 tables; 2026-11-20 17:32:48)

- `tools/sync_tool_catalog_db.py` 10.2.7: the only reader/writer of tools.db (`export`, `import`, `record-call`, `sync`, `verify`, `dump`, one-time `migrate`); additive columns `raw_json` (tools, tool_intents), `aliases_json`, `role`, `domain`, `intent_elevated` (tools), `atom_id` (tool_intents); atom tables per CRP-363; generic `tools.sql` dump of every table.
- `modules/LcmToolCatalog.psm1` 10.2.7: `Get-LcmToolStoreDocument` / `Save-LcmToolStoreDocument`; `Get-LcmToolCatalogData` and `Update-LcmToolIntentCall` on the store.
- Readers/writers switched (no JSON path left): Update-ToolCatalog, LcmAhkAtoms (+test), DaemonActionController, LcmSecurityGateway, LcmDisplayDependencies, Export-LCMRules (mirror = export), Invoke-LCM_Push (commits tools.sql in step 2a), Invoke-LcmAction, Invoke-LcmProtocol, Invoke-PrivilegedTool, LcmDesktopDaemon, Remove-LcmShortName, Show-ToolIntents, Sync-ToolSymlinks, Test-GeneralReadiness, Test-LcmExternalToolDocumentation, Test-RepoReadiness, Sync-LcmCatalogMacros (explicit -CatalogPath = test fixture only), tests ToolIntentMetrics / ToolPermissionLevels / LcmElevatedDaemon (isolated tools.db copy, `LCM_TOOLS_DB_PATH`).
- `config/tool_catalog.json`, `config/tool_intents.json` deleted; entries removed from `config/structure.lock.json` and `config/lcm-path-map.json`; `docs/DataDesign-Tools.md` 10.2.5.
- Remaining steps of this CRP: `strategies.json`, `proposals.json` (with the 117 timestamps), BUG-348 item 1 (routes), `elevation_policy.json` (goes with the CRP-382 data service).
