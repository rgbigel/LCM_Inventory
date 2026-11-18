# Change Request Proposal: BUG-313

```yaml
CRP-ID: BUG-313
Title: [BUG] Repair Action Gateway Argument Preservation, Macrium CLI Syntax & Universal Daemon Dispatch Architecture
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-10 12:25:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
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

---

## 4. Reopening Scope Delta (2026-11-10 Operator Directive)
Per `RULE-LCM-025`, BUG-313 is reopened to absorb the following structural corrections:

1. **Macrium Reflect CLI Syntax Alignment**:
   - Update `Dismount-MacriumCurrentBaseline.ps1`, `LcmMacriumAtoms.psm1`, and `Invoke-MacriumDailyBcrBaseline.ps1` to pass `"$letter`:" '-u'` CLI arguments.
   - Expand parameter normalization in `Dismount-MacriumCurrentBaseline.ps1` to cleanly accept both bare letters (`F`) and colon-suffixed drive letters (`F:`).
2. **Pure Trampoline Architecture**:
   - Trampolines (`*.cmd`) MUST NOT perform administrative, environment, or session tests (`net session`).
   - Trampolines MUST strictly:
     a) Verify that the target script/tool exists (fail with clear error if not found).
     b) Forward execution and all arguments (`%*`) directly to the target script or canonical dispatcher.
3. **In-Script Elevation Self-Governance**:
   - Scripts requiring elevation (`Dismount-MacriumCurrentBaseline.ps1`, etc.) must perform internal privilege validation (`RULE-ELEV-005`).
   - If invoked in standard user context, the script must auto-route through the Port 9876 daemon or fail with explicit elevation guidance rather than triggering interactive UAC stalls (`consent.exe`).
4. **Universal Daemon Dispatch Architecture (Port 9876)**:
   - Transition script and tool invocations to route through the centralized Port 9876 Daemon Gateway, enabling single-point privilege evaluation, session affinity, and execution tracking.

---

## 5. AutoHotkey v2 Automation Atom & Macrium v10 Dialog Handling
1. **Modular AHK Atom (`LcmAhkAtoms.psm1`)**:
   - Exposes `Get-LcmAhkPath`, `Test-LcmAhkAvailable`, `Get-LcmWindowSpyPath`, `Start-LcmWindowSpy`, and `Invoke-LcmAhkScript`.
   - Locates AutoHotkey v2 at canonical path `D:\Tools\AutoHotkey\v2\AutoHotkey64.exe` with fallback to `PATH`.
2. **Macrium Reflect v10 Dialog Automation (`Mount-MacriumBrowseDialog.ahk`)**:
   - Dispatches against `#32770` dialog belonging to `ReflectBin.exe`.
   - Selects partition row 1 in `SysListView321` (`x20 y38`), enabling dependent controls.
   - Sets `Button4` ("Enable access to restricted folders") via `ControlSetChecked(1, "Button4", dialogHwnd)`.
   - Sets `Button5` ("Make writable") via `ControlSetChecked(1, "Button5", dialogHwnd)`.
   - Focuses and activates `Button6` ("OK") with fallback `{Enter}` key dispatch.
   - Emits structured output tokens (`STEP_PARTITION_SELECT: CHECKED`, `STEP_RESTRICTED_FOLDERS: CHECKED`, `STEP_WRITABLE: CHECKED`, `STEP_OK_CLICK: CLICKED`, `STATUS: SUCCESS`).
3. **Pre-BCR Launch Lock Prevention**:
   - `Invoke-MacriumDailyBcrBaseline.ps1` strictly validates that the baseline volume is mounted and the repository container path (`$drive\Git_Repositories`) exists before launching Beyond Compare 5, preventing handle lock contention.


---

## 5. AutoHotkey v2 Automation Atom & Macrium v10 Dialog Handling
1. **Modular AHK Atom (`LcmAhkAtoms.psm1`)**:
   - Exposes `Get-LcmAhkPath`, `Test-LcmAhkAvailable`, `Get-LcmWindowSpyPath`, `Start-LcmWindowSpy`, and `Invoke-LcmAhkScript`.
   - Locates AutoHotkey v2 at canonical path `D:\Tools\AutoHotkey\v2\AutoHotkey64.exe` with fallback to `PATH`.
2. **Macrium Reflect v10 Dialog Automation (`Mount-MacriumBrowseDialog.ahk`)**:
   - Dispatches against `#32770` dialog belonging to `ReflectBin.exe`.
   - Selects partition row 1 in `SysListView321` (`x20 y38`), enabling dependent controls.
   - Sets `Button4` ("Enable access to restricted folders") via `ControlSetChecked(1, "Button4", dialogHwnd)`.
   - Sets `Button5` ("Make writable") via `ControlSetChecked(1, "Button5", dialogHwnd)`.
   - Focuses and activates `Button6` ("OK") with fallback `{Enter}` key dispatch.
   - Emits structured output tokens (`STEP_PARTITION_SELECT: CHECKED`, `STEP_RESTRICTED_FOLDERS: CHECKED`, `STEP_WRITABLE: CHECKED`, `STEP_OK_CLICK: CLICKED`, `STATUS: SUCCESS`).
3. **Pre-BCR Launch Lock Prevention**:
   - `Invoke-MacriumDailyBcrBaseline.ps1` strictly validates that the baseline volume is mounted and the repository container path (`$drive\Git_Repositories`) exists before launching Beyond Compare 5, preventing handle lock contention.


