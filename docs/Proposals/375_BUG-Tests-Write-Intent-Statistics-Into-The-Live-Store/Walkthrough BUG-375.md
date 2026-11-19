# Walkthrough: BUG-375 - Tests Write Intent Statistics Into The Live Store

Module: docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Walkthrough BUG-375.md  
Purpose: Implementation and verification record for BUG-375.  
Path: LCM_Inventory/docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Walkthrough BUG-375.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:54:33

---

| Check | Result |
|:---|:---|
| Probe before the fix (store hashes before/after each test file, child pwsh) | 3 of 11 suspect files changed live stores: `ToolIntentMetrics.Tests.ps1` (tool_intents.json, tool_catalog.json, docs/README.md), `LcmElevatedDaemon.Tests.ps1` (tool_intents.json), `Test-LcmProposalsDb.Tests.ps1` (proposals.db; plus 1 failing case: active items < 100 assumed the live ledger size) |
| Clean before the fix | ContextAbsorption, ControlHubSafety, MacriumBcrReview, ProposalLifecycle, ProposalSpecificationFence, ToolPermissionLevels, InvokeLcmDisplayRender, ReviewStagingIgnoredDirectory |
| AST parse of the 4 changed files | 0 errors |
| Probe after the fix | ToolIntentMetrics 4 passed, LcmElevatedDaemon 14 passed, Test-LcmProposalsDb 10 passed; 0 live stores changed |

## Reset (2026-11-19 21:17:37)

- Operator decision executed: `call_count` set to 0 and `last_called_at` to null for all 683 intents of
  `config/tool_intents.json` (in-place text replacement, formatting kept; 616 recorded calls before, 0 after); backup
  `scratch/db-dumps/tool_intents-before-bug375-reset.json`; `Sync-LcmToolCatalogDb -Action Sync`: JSON and `tools.db`
  identical (0 differing rows).
