# Change Request Proposal: CRP-316

```yaml
CRP-ID: CRP-316
Title: Trampoline Window Caller Context and Goal Identification Header
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-10 20:18:32
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
When an LCM command trampoline (`Cmd/*.cmd`) launches a PowerShell (`pwsh.exe`) session, it shall display an identification banner in the PowerShell window. This banner identifies the caller (the invoking trampoline script name) and the goal of the shell invocation (the designated tool goal/description from the tool catalog). This provides clear visual context and auditing in interactive and automated console windows.

---

## 2. Gate 0 Contract

### Target State
1. All generated and maintained command trampolines launching `pwsh.exe` include a clean identification header displayed upon launch.
2. The header reports:
   - **Caller**: The trampoline filename (`%~nx0`, e.g. `ShowTools.cmd`, `AbsorbLcmContextRemark.cmd`).
   - **Goal**: The explicit functional goal/purpose of the tool (sourced from `tool_catalog.json` / `tool_intents.json`).
3. The display formatting is unobtrusive, deterministic, and does not alter or corrupt command exit codes (`%ERRORLEVEL%`) or argument passing (`%*`).

### Invariants and Exit Criteria
- **Formatting Invariant**: The banner is cleanly formatted (e.g. cyan or standard console text banner) and appears at the very start of the shell execution.
- **Pass-through Invariant**: Argument forwarding (`$args` / `%*`) and exit code propagation remain 100% transparent and intact.
- **Generator Parity**: `Update-ToolCatalog.ps1` generates the banner logic consistently across all PowerShell trampolines in `LCM_Inventory/Cmd/`.

### Explicit Non-Goals
- Modifying non-PowerShell trampolines (e.g. pure batch or python callers) beyond standard banner consistency if not applicable.
- Altering the underlying tool execution semantics or arguments.

---

## 3. Technical Requirements & Invariants
- `Update-ToolCatalog.ps1`: Update trampoline generation logic to inject the caller and goal identification banner when launching `pwsh.exe`.
- Existing manually crafted trampolines in `LCM_Inventory/Cmd/` updated to match the standard banner pattern.
- Verified with Pester testing to confirm arguments and errorlevels pass through without interference.
