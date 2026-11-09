# Implementation Plan: BUG-313 - Repair Action Gateway CLI Argument Preservation and Port 9876 Direct Intent Completion

## 1. Executive Summary & Problem Context
When accepting a proposal review in `CM_CONTROL_HUB.html`, clicking "ACCEPTED: Item" dispatches a request to Port 9876 `/api/action`.
`DaemonActionController.ps1` matched the target against `tool_catalog.json` using substring matching (`-like "*$($_.RelativePath)*"`). Upon finding a match, it replaced the entire invocation with only the script path and checked for `$intent.Parameters`. Because the frontend passed the full command string in `$intent.Target` and `$intent.Command` rather than a structured parameter dictionary, `$intent.Parameters` was empty. All arguments (`-RepositoryPath LCM_Inventory -CRP CRP-310 -Result Completed`) were stripped, causing `Submit-ReviewResult.ps1` to run bare and throw `-CRP is required`.

## 2. Gate 0 Traceability
- **Clause 1**: Update `DaemonActionController.ps1` so `ExecuteActionIntent` extracts and preserves trailing arguments from `$intent.Target` or forwards `$intent.Command` directly when `$intent.Parameters` is empty.
- **Clause 2**: Update `CM_CONTROL_HUB.html` review acceptance logic to ensure clean parameters and robust fallback.
- **Clause 3**: Add Pester tests verifying `ExecuteActionIntent` argument retention.

## 3. Proposed Changes
### Component 1: `DaemonActionController.ps1`
- Refactor lines 398-485 in `DaemonActionController.ps1`:
  - When `$intent.Command` is provided and `$intent.Parameters` is empty, check whether it is a CLI invocation with arguments. If so, preserve those arguments.
  - When `$intent.Target` contains arguments after the script/tool name (e.g. `pwsh ... -File script.ps1 arg1 arg2`), parse and preserve the arguments.
  - When matching against `tool_catalog.json`, extract any trailing command text after the matched script/tool name if `$intent.Parameters` is empty.

### Component 2: `CM_CONTROL_HUB.html`
- Update `dispatchStandardAction('reviewed', ...)` to send structured `DaemonActionIntent` DTO:
  ```json
  {
    "action": "DO",
    "target": "Submit-ReviewResult",
    "parameters": {
      "RepositoryPath": repo,
      "CRP": crpTag,
      "Result": "Completed"
    },
    "options": { "sync": true },
    "caller": "ControlHub"
  }
  ```
  This transfers the command line formatting logic out of JavaScript and into the daemon DTO layer.

## 4. Verification Plan
- Pester unit tests in `LCM_Inventory/tests/LcmElevatedDaemon.Tests.ps1`.
- Direct test of `Submit-ReviewResult.ps1` via daemon action intent.
- `Test-GeneralReadiness.ps1` on `LCM_Inventory`.
