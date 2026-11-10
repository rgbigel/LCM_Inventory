# Implementation Plan: CRP-308

```yaml
CRP-ID: CRP-308
Document: Implementation_Plan
Title: GoodMorning Baseline Visibility, Default BCR Preparation, and Macrium Automation Atoms
Scope: LCM_Inventory
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 16:55:00
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Overview
Decomposes `Invoke-MacriumDailyBcrBaseline.ps1` into modular atoms in `LCM_Inventory/modules/LcmMacriumAtoms.psm1`, integrates `Get-MacriumBaselineState` into `Invoke-LCM_GoodMorning.ps1`, renders unconditional baseline telemetry, and sets `$PrepareBcrBaseline` default to `$true`.

---

## 2. Step-by-Step Execution Plan

### Step 1: Create `LCM_Inventory/modules/LcmMacriumAtoms.psm1`
- Extract and standardize the modular atoms:
  - `Get-MacriumBaselineState`: Reads registry telemetry from `HKLM:\SOFTWARE\LCM\MacriumBaseline` and checks logical disk mounts for volume label `D4P3-WDB850-D`.
  - `Get-MacriumBackupStatus`: Scans Macrium Reflect HTML reports and backup directory for completed same-day images.
  - `Start-MacriumBackup`: Starts backup process via Reflect definition file.
  - `Mount-MacriumBaseline`: Executes elevated worker UI mount automation.
  - `Dismount-MacriumBaseline`: Detaches image mounts and closes review sessions.
- Export all functions conforming to `RULE-PS-002` (approved verbs).

### Step 2: Refactor `tools/Invoke-MacriumDailyBcrBaseline.ps1`
- Import `LcmMacriumAtoms.psm1`.
- Delegate high-level workflow steps to the atoms while maintaining exact CLI parameter compatibility.

### Step 3: Update `tools/Invoke-LCM_GoodMorning.ps1`
- Import `LcmMacriumAtoms.psm1`.
- Update parameter block:
  - `[switch]$PrepareBcrBaseline = $true`
  - `[switch]$NoBaseline` (to optionally suppress preparation).
- Add unconditional `[BASELINE]` reporting section in `Invoke-LCM_GoodMorning.ps1` summary calling `Get-MacriumBaselineState`:
  - Output registered backup timestamp and drive from registry.
  - Output whether the drive is currently mounted.
  - Output snapshot date/time and GoodNight observation status.

### Step 4: Verification & Quality Gates
- Execute AST syntax verification (`RULE-PS-021`) across all modified and new files.
- Test `Get-MacriumBaselineState` execution against currently mounted drive `F:`.
- Test `Invoke-LCM_GoodMorning.ps1` output to ensure complete baseline summary rendering.
- Verify `RULE-DOC-009` comment preservation and run `Test-RepoReadiness.ps1`.
