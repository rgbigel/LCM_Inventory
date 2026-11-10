# Change Request Proposal: CRP-312

```yaml
CRP-ID: CRP-312
Title: [FEAT] Dedicated Show-ToolIntents Viewer and ShowTools Explorer Integration
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-11-09 18:32:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Add a dedicated `Show-ToolIntents.ps1` tool (with `Cmd/ShowToolIntents.cmd` trampoline) and integrate a "Tool Intents" launch button into the existing `Show-ToolsExplorer.ps1` HTML topbar/controls to view, filter, and inspect the complete catalog of operational intents (`tool_intents.json`).

## 2. Gate 0 Contract
### Target State
- `Show-ToolIntents.ps1` provides an interactive, search-enabled standard display viewer for `tool_intents.json`.
- `Cmd/ShowToolIntents.cmd` trampoline allows instant execution.
- `Show-ToolsExplorer.ps1` includes a topbar action button labeled "Tool Intents" (`Show-Tool-Intents`) linking or launching `Show-ToolIntents.ps1`.
- Tests verify presence, parameter contracts, and syntax.

### Invariants and Exit Criteria
- Conforms to `RULE-DSP-001` - `016` (Antigravity-IDE Light Mode standard display).
- Passes all 6/6 quality gates in `Test-GeneralReadiness.ps1`.
- Pester unit tests pass 100%.

### Explicit Non-Goals
- Modifying underlying SQLite database transition (CRP-311).
