# Implementation Plan: BUG-375 - Tests Write Intent Statistics Into The Live Store

Module: docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Implementation Plan BUG-375.md  
Purpose: Concrete changes per file for BUG-375 and its open item.  
Path: LCM_Inventory/docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Implementation Plan BUG-375.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:54:33

---

| File | Change |
|:---|:---|
| `modules/LcmToolCatalog.psm1` 10.2.6 | `Update-LcmToolIntentCall`: store from `LCM_TOOL_INTENTS_PATH` when set, else `config/tool_intents.json` relative to the module (no fixed drive path) |
| `tests/ToolIntentMetrics.Tests.ps1` | rewritten: works on a TestDrive copy; new case "leaves the live store untouched" (hash check); generator carry-over checked in the source instead of a live generator run |
| `tests/LcmElevatedDaemon.Tests.ps1` 10.2.3 | the controller's statistics go to a TestDrive copy (`LCM_TOOL_INTENTS_PATH`), restored in `AfterAll` |
| `tests/Test-LcmProposalsDb.Tests.ps1` | sync / verify / query / hydrate on TestDrive copies of the ledger files; the active-horizon check no longer depends on the live ledger size |

## Open Item (operator decision)

- The statistics in `config/tool_intents.json` are already polluted by earlier gate runs and cannot be separated from
  real calls: reset them once (call_count, last_called_at, last_duration_ms, total_duration_ms to their initial values)
  or keep them and count correctly from now on.

## Operator Decisions (2026-11-19 19:24:11)

- The existing intent call statistics are reset once (call_count 0, last_called_at empty); from then on only real calls count.
