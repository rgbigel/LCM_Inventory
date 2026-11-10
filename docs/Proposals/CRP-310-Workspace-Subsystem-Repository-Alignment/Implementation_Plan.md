# Implementation Plan: CRP-310

```yaml
CRP-ID: CRP-310
Document: Implementation_Plan
Title: Workspace-Wide Subsystem and Repository Alignment with LCM Port 9876 Architecture
Scope: Workspace Cohort (LCM_Inventory, HaSSD06, HaSSD06_Inventory, LCM_Tools, OneDriveMaintenance)
Cohort-ID: COH-310
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 17:47:00
Status: Verified
Plan-State: completed
Progress-State: completed
Priority: High
App-ID: APP-001
```

---

## 1. Overview
Aligns all LCM-governed child repositories and subsystems with the Port 9876 elevated daemon, eliminates speculative relative pathing (`../`), establishes a two-step readiness testing standard, repairs rule junctions, and migrates remaining frontend dispatchers to typed Action Intent DTOs.

---

## 2. Step-by-Step Execution Plan

### Step 1: Repair Rule Reparse Points (Junctions)
- **Target Repositories**: `LCM_Tools`, `OneDriveMaintenance`
- Create `.agents\rules` junction in `D:\Git_Repositories\LCM_Tools`.
- Remove physical stale directory `D:\Git_Repositories\OneDriveMaintenance\.agents\rules` and create junction.
- Verify 21/21 repositories have active junctions to `D:\Git_Repositories\LCM_AI\.agents\rules`.

### Step 2: Implement `Test-GeneralReadiness.ps1`
- **Location**: `LCM_Inventory/tools/Test-GeneralReadiness.ps1`
- Implement universal quality gate:
  - Validates `.agents/rules` junction points to `LCM_AI/.agents/rules`.
  - Validates UTF-8 without BOM on source files.
  - Validates AST parse syntax across all PowerShell files (`RULE-PS-021`).
  - Validates Python syntax compilation across all `*.py` files (`RULE-PY-001`).
  - Validates `.gitignore` exclusion of secrets, logs, and temporary artifacts.
- Return structured PSCustomObject and exit code 0 on pass / 1 on failure.

### Step 3: Align HaSSD06 Subsystem Repositories
- **Target Repositories**: `HaSSD06`, `HaSSD06_Inventory`
- In `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`:
  - Replace all `../HaSSD06/...` and `../LCM_Inventory/...` paths with `HaSSD06/...` and `LCM_Inventory/tools/...`.
  - Update `dispatchCommand()` to post Action Intent DTOs to `http://127.0.0.1:9876/api/action`.
- In `HaSSD06_Inventory/tools/Update-HaInventory.ps1`:
  - Replace all `../` speculative paths in `tools_catalog` array.
- In `HaSSD06_Inventory/tools/Test-RepoReadiness.ps1`:
  - Delegate Step 1 to `LCM_Inventory/tools/Test-GeneralReadiness.ps1`.
  - Execute Step 2 for domain inventory schema, Core version, and secrets isolation.
- In `HaSSD06/tools/Test-RepoReadiness.ps1`:
  - Delegate Step 1 to `LCM_Inventory/tools/Test-GeneralReadiness.ps1`.
  - Execute Step 2 for tripartite documentation specifications.

### Step 4: Migrate Control Hub Dispatchers
- **Target File**: `LCM_Inventory/assets/CM_CONTROL_HUB.html`
- Update `dispatchWorkspaceSwitch()` (line 3280) to send `{ action: 'DO', target: 'RunProposalAction', parameters: { Action: atomName, SwitchState: targetState }, caller: 'ControlHub' }` to `/api/action`.
- Update `dispatchCommandDirect()` (line 3805) to send typed Action Intents to `/api/action`.

### Step 5: Standard Display `-Pane` / `-Panel` Parity & Documentation
- **Target Files**:
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
- Add `[Alias('Panel')]` and `[switch]$Pane` parameter across all listed tools.
- Add `.PARAMETER Pane` to the comment-based help block of each script.
- Ensure `-Pane:$Pane` is forwarded to `Open-LcmStandardDisplay` and `Invoke-InteractiveDesktop.ps1`.

### Step 6: Verification & Multi-Repository Cohort Review
- Execute `Test-GeneralReadiness.ps1` across `LCM_Inventory`, `HaSSD06`, and `HaSSD06_Inventory`.
- Execute local `Test-RepoReadiness.ps1` in both `HaSSD06` and `HaSSD06_Inventory`.
- Scan entire workspace to confirm 0 speculative `../` paths remain.
- Execute `Test-LCMIncrementalGovernance.ps1`.
- Open visual review gate via Beyond Compare (`bcr 310`).
