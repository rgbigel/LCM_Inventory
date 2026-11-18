# Change Request Proposal: CRP-310 (Master Alignment Proposal)

```yaml
CRP-ID: CRP-310
Title: Workspace-Wide Subsystem and Repository Alignment with LCM Port 9876 Architecture
Scope: Workspace Cohort (LCM_Inventory, HaSSD06, HaSSD06_Inventory, LCM_Tools, OneDriveMaintenance)
Cohort-ID: COH-310
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 17:47:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: High
App-ID: APP-001
Supersedes: None
```

---

## 1. Executive Summary & Intent

Align all LCM-governed child repositories and subsystems with the unified Port 9876 elevated daemon, universal command gateway (`lcm do`), and two-step readiness quality gate architecture established in `CRP-309` and `CRP-308`.

This proposal comprehensively resolves:
1. **Speculative Relative Pathing (`../`) in Subsystems**: Eliminates all occurrences of fragile `../` paths in `HaSSD06_Inventory` (`Show-HaInventoryApp.ps1` and `Update-HaInventory.ps1`) that break when dispatched from the workspace root.
2. **Subsystem Action Gateway Integration & Frontend Logic Extraction**: Upgrades `Show-HaInventoryApp.ps1` to extract business logic and command assembly out of the frontend HTML, dispatching structured Action Intent DTOs (`{ action: 'DO', target: '...', caller: 'HaSSD06' }`) via the Port 9876 `/api/action` endpoint.
3. **Control Hub Gateway Migration**: Migrates `CM_CONTROL_HUB.html` switch buttons and direct commands from raw `/execute` strings to typed `/api/action` intents.
4. **Standard Display `-Pane` / `-Panel` Parity & Documentation**: Standardizes the `-Pane` switch with `[Alias('Panel')]` and complete `.PARAMETER Pane` comment-based help across all Standard Display tools (`Show-LcmControl.ps1`, `Show-ToolsExplorer.ps1`, `Show-Rules.ps1`, `Show-LCM_InventoryApp.ps1`, `Show-LCM_Readiness.ps1`, `Show-LcmAnalysisViewer.ps1`, `Show-FailureAnalysis.ps1`, `Show-HaInventoryApp.ps1`, `Open-LcmStandardDisplay`, and `Invoke-InteractiveDesktop.ps1`).
5. **Two-Step Readiness Testing Architecture**: Implements `Test-GeneralReadiness.ps1` in `LCM_Inventory` for universal workspace rules, and links repository-specific readiness checks (`Test-HaSSD06Readiness.ps1`, `Test-LCM_Readiness.ps1`) to run general tests first followed by domain specifics.
6. **Rule Junction Discovery Parity**: Creates the missing `.agents\rules` junction in `LCM_Tools` and replaces the stale physical copy in `OneDriveMaintenance` with an authoritative junction to `LCM_AI\.agents\rules`.

---

## 2. Gate 0 Contract

### Target State
1. **Zero Speculative Pathing**: No `*.ps1`, `*.py`, `*.js`, or `*.html` files in any governed repository reference `../HaSSD06` or `../LCM_Inventory`. All cross-repository references are strictly workspace-relative (`HaSSD06/...`, `LCM_Inventory/...`).
2. **Subsystem Gateway Dispatch**: Clicking "Run" or "Dispatch" in `Show-HaInventoryApp.ps1` dispatches through the Port 9876 `/api/action` Gateway with live terminal output streaming to the feedback drawer.
3. **Rule Reparse Point Parity (21/21)**: Every governed repository in `D:\Git_Repositories` contains an active `.agents\rules` reparse point linking directly to `LCM_AI\.agents\rules`.
4. **Two-Step Readiness Standard**:
   - Step 1: `LCM_Inventory\tools\Test-GeneralReadiness.ps1` tests universal repository rules (reparse points, headers, UTF-8 BOM, AST syntax).
   - Step 2: Local `tools\Test-RepoReadiness.ps1` calls Step 1 then executes repository/subsystem specific domain checks.
5. **Control Hub Frontend Alignment**: `CM_CONTROL_HUB.html` dispatches switch toggles and direct commands using typed `{ action: 'DO', target: '...' }` intents to `/api/action`.
6. **Standard Display `-Pane` / `-Panel` Parity**: Every Standard Display CLI script exposes `[Alias('Panel')][switch]$Pane` with full `.PARAMETER Pane` documentation and forwards `-Pane:$Pane` to the desktop daemon / IDE pane dispatcher.

### Invariants & Quality Standards
- **RULE-LCM-001**: Proposal-first intent; no unapproved cross-repo edits.
- **RULE-PS-002**: Microsoft-approved verbs across all new and updated scripts.
- **RULE-PS-021**: Mandatory pre-handoff AST syntax pass with 0 errors across all touched files.
- **RULE-EFF-008**: Zero speculative relative pathing across the entire workspace.
- **RULE-DOC-009**: Complete comment and documentation preservation.

### Explicit Non-Goals
- Altering Home Assistant configuration YAML files on the physical HaSSD06 host.
- Modifying Git history or tags in any child repository.
- Re-architecting Macrium Reflect backup XML definitions.

---

## 3. Step-by-Step Implementation Strategy

### Work Package 1: Subsystem Path Correction (`HaSSD06_Inventory`)
- Update `Show-HaInventoryApp.ps1` (`HA_TOOLS_CONFIG`): Replace `../HaSSD06/...` and `../LCM_Inventory/...` with deterministic workspace paths (`HaSSD06/...`, `LCM_Inventory/tools/...`).
- Update `Update-HaInventory.ps1` (`tools_catalog`): Standardize all tool paths to workspace-relative paths.
- Upgrade `dispatchCommand()` in `Show-HaInventoryApp.ps1` to send `{ action: 'DO', target: toolName, parameters: params, caller: 'HaSSD06' }` to `http://127.0.0.1:9876/api/action`.

### Work Package 2: Control Hub Intent Migration (`LCM_Inventory`)
- Update `dispatchWorkspaceSwitch()` in `CM_CONTROL_HUB.html` to post `{ action: 'DO', target: 'RunProposalAction', parameters: { Action: atomName, SwitchState: targetState }, caller: 'ControlHub' }` to `/api/action`.
- Update `dispatchCommandDirect()` to post typed Action Intents to `/api/action`.

### Work Package 3: Universal Two-Step Readiness Quality Gates
- Create `LCM_Inventory/tools/Test-GeneralReadiness.ps1`:
  - Parameter `-RepositoryPath <string>` (defaults to current directory).
  - Validates `.agents/rules` junction target.
  - Validates UTF-8 without BOM encoding on source files.
  - Validates PowerShell AST syntax across all `*.ps1`/`*.psm1`.
  - Validates Python syntax compilation across all `*.py`.
  - Validates `.gitignore` exclusion of secrets and scratch directories.
- Refactor `HaSSD06_Inventory/tools/Test-RepoReadiness.ps1` to invoke `Test-GeneralReadiness.ps1` for Step 1, then execute Step 2 domain inventory and core version verification.
- Refactor `HaSSD06/tools/Test-RepoReadiness.ps1` to invoke `Test-GeneralReadiness.ps1` for Step 1, then execute Step 2 tripartite doc and Python AST checks.

### Work Package 4: Reparse Point Parity
- Create junction in `LCM_Tools\.agents\rules` -> `D:\Git_Repositories\LCM_AI\.agents\rules`.
- Remove physical stale directory `OneDriveMaintenance\.agents\rules` and create junction -> `D:\Git_Repositories\LCM_AI\.agents\rules`.

### Work Package 5: Standard Display `-Pane` / `-Panel` Parity & Documentation
- Standardize `[Parameter(Mandatory = $false, HelpMessage = 'Opens the display inside an Antigravity IDE editor/side pane')][Alias('Panel')][switch]$Pane` across:
  - `LCM_Inventory/tools/Show-LcmControl.ps1`
  - `LCM_Inventory/tools/Show-ToolsExplorer.ps1`
  - `LCM_Inventory/tools/Show-Rules.ps1`
  - `LCM_Inventory/tools/Show-LCM_InventoryApp.ps1`
  - `LCM_Inventory/tools/Show-LCM_Readiness.ps1`
  - `LCM_Inventory/tools/Show-LcmAnalysisViewer.ps1`
  - `LCM_Inventory/tools/Show-FailureAnalysis.ps1`
  - `LCM_Inventory/modules/LcmStandardDisplay.psm1`
  - `LCM_Inventory/tools/Invoke-InteractiveDesktop.ps1`
  - `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`
- Add `.PARAMETER Pane` description to comment-based help blocks for every updated tool.
- Ensure `-Pane:$Pane` is propagated to `Open-LcmStandardDisplay` and `Invoke-InteractiveDesktop.ps1`.

---

## 4. Verification & Exit Criteria
1. `pwsh LCM_Inventory/tools/Test-GeneralReadiness.ps1 -RepositoryPath <path>` passes against `LCM_Inventory`, `HaSSD06`, and `HaSSD06_Inventory`.
2. `pwsh HaSSD06_Inventory/tools/Test-RepoReadiness.ps1` passes 100% (both general and subsystem gates).
3. `pwsh HaSSD06/tools/Test-RepoReadiness.ps1` passes 100%.
4. Reparse point audit reports 21/21 repositories have active junctions to `LCM_AI\.agents\rules`.
5. Speculative relative path scan reports **0 occurrences** across all repositories.
6. Incremental governance gate `Test-LCMIncrementalGovernance.ps1` passes 100% with 0 violations.
