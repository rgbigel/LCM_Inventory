# Change Request Proposal: BUG-313

```yaml
CRP-ID: BUG-313
Title: [BUG] Repair Action Gateway CLI Argument Preservation and Port 9876 Direct Intent Completion
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-09 19:01:08
Status: In_Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Fix `ExecuteActionIntent` in `DaemonActionController.ps1` to prevent stripping CLI arguments when a command matches a script in `tool_catalog.json` without an explicit `parameters` dictionary. When raw CLI commands or commands with inline arguments are submitted, all arguments must be preserved.
In addition, transfer client-side review completion logic out of `CM_CONTROL_HUB.html` by ensuring that `Submit-ReviewResult` can be invoked cleanly both via structured `DaemonActionIntent` DTOs and via command dispatching without argument loss.

## 2. Gate 0 Contract
### Target State
1. `ExecuteActionIntent` in `DaemonActionController.ps1` preserves arguments when:
   - `$intent.Command` is populated and has arguments.
   - `$intent.Target` is a CLI string containing arguments or matching a tool path with trailing parameters.
   - `$intent.Parameters` is populated as a dictionary.
2. In `CM_CONTROL_HUB.html`, reviewing/accepting an item or cohort transmits valid parameters (`-CRP <CRP-ID>`, `-RepositoryPath <Repo>`, `-Result Completed`), allowing `Submit-ReviewResult.ps1` to accept the review without throwing `-CRP is required`.

### Invariants and Exit Criteria
- `ExecuteActionIntent` must never execute `Submit-ReviewResult.ps1` (or any other tool) bare if arguments were passed in `$intent.Command` or trailing `$intent.Target`.
- Syntax and AST validation on all touched files must pass with 0 errors (`RULE-PS-021`).
- `Submit-ReviewResult.ps1` invocation with `-CRP CRP-310` must proceed to legitimate review acceptance.

### Explicit Non-Goals
- Cause no havoc; avoid unnecessary refactoring of unaffected daemon routes.

## 3. Technical Requirements & Invariants
- Invariant 1: Preserve all arguments passed in `$intent.Command` or `$intent.Target`.
- Invariant 2: UTF-8 without BOM encoding on all edited files (`JSON-RULES`, `POWERSHELL-RULES`).
- Invariant 3: Pester tests verifying both structured parameter calls and raw CLI command calls to `ExecuteActionIntent`.
