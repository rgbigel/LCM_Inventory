# Implementation Plan: CRP-315 - Track Tool Intent Usage Metrics, Millisecond Timestamps and Computational Cost

## 1. Executive Summary & Problem Context
Tool access frequency and execution duration are critical metrics for workflow optimization. ToolIntents ledger (`config/tool_intents.json`) provides the central repository substrate for this data. This plan adds schema support, runtime recording on dispatch, catalog preservation, and UI presentation.

## 2. Proposed Changes
### Component 1: Usage Metrics Schema & Tracking Cmdlet
- Create/export `Update-LcmToolIntentCall` in `LCM_Inventory/modules/LcmToolCatalog.psm1` (or dedicated module).
- Reads `config/tool_intents.json`, matches tool by script path, executable command, or intent name.
- Updates `call_count`, `last_called_at` (format: `yyyy-MM-dd HH:mm:ss.fff`), `last_duration_ms`, `total_duration_ms`.
- Atomic thread-safe file persistence.

### Component 2: Action Gateway & Daemon Dispatch Hook
- Update `LCM_Inventory/modules/LcmDaemon/Classes/DaemonActionController.ps1` to call `Update-LcmToolIntentCall` after command execution with measured duration.
- Update `LCM_Inventory/tools/Invoke-LcmAction.ps1` to also record direct CLI tool dispatches.

### Component 3: Catalog Synchronization Preservation
- Update `LCM_Inventory/tools/Update-ToolCatalog.ps1` to read existing `tool_intents.json` and carry forward `call_count`, `last_called_at`, `last_duration_ms`, and `total_duration_ms` when re-indexing intents.

### Component 4: Show-ToolIntents Presentation
- Update `LCM_Inventory/tools/Show-ToolIntents.ps1` to display `Calls`, `Last Called`, and `Duration` columns.

### Component 5: Tests & Advice Retirement (RULE-LCM-031)
- Create `LCM_Inventory/tests/ToolIntentMetrics.Tests.ps1` covering metric updates, millisecond formatting, and catalog preservation.
- Execute `Link-LcmLearnedAdvice.ps1 -Id 315 -PurgeGuaranteed -GuaranteeEvidence "CRP-315 ToolIntentMetrics.Tests.ps1 verified"` to safely drop from `LEARNED_ADVICE.md`.

## 3. Verification Plan
- Run `ToolIntentMetrics.Tests.ps1`.
- Verify `tool_intents.json` contains millisecond precision timestamps.
- Validate AST syntax on all modified PowerShell files.
- Run `Test-GeneralReadiness.ps1 -Repo LCM_Inventory`.
