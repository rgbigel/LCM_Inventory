# Change Request Proposal: CRP-308

```yaml
CRP-ID: CRP-308
Title: GoodMorning Baseline Visibility, Default BCR Preparation, and Macrium Automation Atoms
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-07 14:23:11
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Enhance the LCM GoodMorning startup sequence to provide complete visibility into the Macrium BCR baseline state, make baseline readiness active by default, and decompose the monolithic `Invoke-MacriumDailyBcrBaseline.ps1` script into discrete, composable automation atoms.

---

## 2. Gate 0 Contract

### Target State
1. **Unconditional Baseline Telemetry**: Regardless of parameter settings, `Invoke-LCM_GoodMorning.ps1` always renders a `[BASELINE]` section in its summary report displaying:
   - The registered backup timestamp (`MRMTimeStamp`) and drive (`MRMdrive`) from `HKLM:\SOFTWARE\LCM\MacriumBaseline` / `HKLM:\SOFTWARE\LCM`.
   - Physical mount determination: whether the drive indicated in the registry (or candidate drives F:-I:) is currently mounted with expected volume label `D4P3-WDB850-D`.
   - The exact snapshot date/time and GoodNight observation status of the mounted baseline (from `ACTIVE_CONTEXT.md` on the mounted drive).
2. **Default BCR Baseline Preparation**: The default of parameter `$PrepareBcrBaseline` in `Invoke-LCM_GoodMorning.ps1` is changed to `$true` (with an explicit `-NoBaseline` / `-SkipBaseline` switch or `$false` override available).
3. **Decomposition into Reusable Macrium Atoms**: The responsibilities of `Invoke-MacriumDailyBcrBaseline.ps1` are decomposed into modular, reusable PowerShell atoms in `LCM_Inventory/modules/LcmMacriumAtoms.psm1`:
   - `Get-MacriumBaselineState`: Fast, read-only inspection of registry telemetry, drive mounting, volume labels, and snapshot timestamps.
   - `Get-MacriumBackupStatus`: Evaluates completed same-day `.mrimgx` images and active backup process status.
   - `Start-MacriumBackup`: Initiates backup execution via the configured XML definition file.
   - `Mount-MacriumBaseline`: Executes elevated worker UI mount automation.
   - `Dismount-MacriumBaseline`: Closes Beyond Compare review windows and unmounts image partitions.
4. **GoodMorning Integration**: `Invoke-LCM_GoodMorning.ps1` consumes `Get-MacriumBaselineState` directly for zero-latency, non-elevated summary rendering.

### Invariants and Exit Criteria
- **RULE-DOC-009**: All comments, documentation, and existing parameter behaviors preserved.
- **RULE-PS-002**: 100% Microsoft-approved verb compliance across all exported atom functions.
- **RULE-PS-021**: All atom modules and modified scripts pass native AST parse gate with 0 syntax errors.
- **Fast-Path Preservation**: Existing mounted baselines continue to be reused without unneeded remounts during the workday.

### Explicit Non-Goals
- Modifying Macrium Reflect backup XML definition contents.
- Altering the operator-owned `_LCM` Beyond Compare profile settings in `BCSessions.xml`.
- Modifying external repository files outside `LCM_Inventory`.

---

## 3. Technical Requirements & Implementation Details

1. **Registry Telemetry Resolution**:
   - Inspects `HKLM:\SOFTWARE\LCM\MacriumBaseline` and fallback `HKLM:\SOFTWARE\LCM`.
   - Resolves `MRMTimeStamp`, `MRMdrive`, `ActMTimeStamp`, and `MRPushTimeStamp`.
2. **Drive Mount Verification**:
   - Queries `Win32_LogicalDisk` for candidate drives `F:`, `G:`, `H:`, `I:`.
   - Matches volume label against `D4P3-WDB850-D` and verifies `X:\Git_Repositories` container existence.
3. **GoodMorning Parameter Signature**:
   - `[switch]$PrepareBcrBaseline = $true`
   - Added `[switch]$NoBaseline` to allow running GoodMorning in pure read-only mode without triggering baseline preparation.
