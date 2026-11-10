# Change Request Proposal: CRP-315

```yaml
CRP-ID: CRP-315
Title: Track Tool Intent Usage Metrics, Millisecond Timestamps and Computational Cost
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-10 19:05:51
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Add structured usage metrics (`call_count`, `last_called_at` with millisecond precision, `last_duration_ms`, `total_duration_ms`) to the Tool Intents ledger (`config/tool_intents.json`). Automatically update these fields upon tool dispatch in the LCM Action Gateway / Daemon, preserve metrics during catalog synchronizations, and display them in Show-ToolIntents. Upon verified test coverage, safely retire the corresponding learned advice entry under RULE-LCM-031.

---

## 2. Gate 0 Contract
### Target State
1. Every tool intent in `config/tool_intents.json` contains:
   - `call_count` (int, default 0)
   - `last_called_at` (string, ISO or `yyyy-MM-dd HH:mm:ss.fff` millisecond precision, null when never called)
   - `last_duration_ms` (double, duration of last execution)
   - `total_duration_ms` (double, accumulated duration)
2. Tool execution through the elevated daemon (`DaemonActionController.ps1`) or `Invoke-LcmAction.ps1` resolves the corresponding tool intent and atomically updates the usage metrics in `tool_intents.json`.
3. Catalog synchronization via `Update-ToolCatalog.ps1` preserves existing usage telemetry across refreshes.
4. `Show-ToolIntents.ps1` exposes `-SortBy Calls|LastCalled|Duration` and displays usage columns.
5. Exit Criteria: 100% passing Pester unit tests verifying field population, millisecond timestamps, call-count increments, and advice retirement via `Link-LcmLearnedAdvice.ps1`.

### Invariants and Exit Criteria
- **Millisecond Precision Invariant**: `last_called_at` MUST record timestamps with millisecond precision (`.fff`).
- **Telemetry Retention Invariant**: Catalog regeneration MUST NOT overwrite or reset recorded `call_count`, `last_called_at`, or durations.
- **Reverse-the-Ticket Retirement Invariant (RULE-LCM-031)**: The learned advice entry remains binding until test harness validation passes, whereupon it is safely purged.

### Explicit Non-Goals
- Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
- Individual tool scripts are not modified with bespoke logging boilerplate; dispatch tracking occurs centrally at the action/daemon gateway.

---

## 3. Technical Requirements & Invariants
1. `LcmToolCatalog.psm1` or dedicated helper exposes `Update-LcmToolIntentCall` cmdlet taking `-CommandOrPath <string>`, `-DurationMs <double>`, and `-Timestamp <datetime>`.
2. `DaemonActionController.ps1` dispatches `Update-LcmToolIntentCall` asynchronously upon process completion.
3. `Update-ToolCatalog.ps1` reads existing `config/tool_intents.json` and preserves all 4 usage fields during catalog rebuilds.
4. `Show-ToolIntents.ps1` includes `Calls`, `Last Called`, and `Duration` columns in console and HTML outputs.

---

## Recognized Learned Advice (RULE-LCM-031)
- **Status**: RECOGNIZED (Pending Test Guarantee)
- **Recognized Timestamp**: 2026-11-10 19:06:09
- **Governed Advice**:
> **2026-11-09** (Tool Intents Optimization Metrics): The Show-ToolIntents catalog is designated as the repository substrate for tracking tool access frequencies and relative computational cost for future workflow and AI speed optimizations.
- **Exit Criteria**: Deletion from LEARNED_ADVICE.md requires passing verification harness and codification guarantee.
