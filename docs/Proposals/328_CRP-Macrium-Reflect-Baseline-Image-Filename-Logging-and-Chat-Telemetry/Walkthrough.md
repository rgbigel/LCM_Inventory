# Walkthrough: CRP-328 - Macrium Reflect Baseline Image Filename Logging and Chat Telemetry

**Document Information**
- **Proposal ID**: CRP-328
- **Title**: Macrium Reflect Baseline Image Filename Logging and Chat Telemetry
- **Author**: Rolf & Antigravity
- **Date**: 2026-11-14
- **Status**: Completed / Verified

---

## 1. Overview & Verification Summary
`CRP-328` establishes end-to-end logging, registry persistence, console prominence, and durable agent chat disclosure of the exact Macrium Reflect backup image (`.mrimgx`) file and full path whenever a baseline is mounted, checked, or reviewed.

---

## 2. Changes Made

### 1. `LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1`
- **Fast-Path Reuse**: Resolves the active image path (`$resolvedImagePath`) from same-day completed image metadata or registry `MRMImagePath`, and extracts the leaf filename (`$resolvedImageLeaf`). Populates `ImagePath` and `ImageFileName` in the returned PSCustomObject instead of returning an empty string.
- **Fresh Mount**: Writes `MRMImagePath`, `MRMImageLeaf`, `actMImagePath`, and `actMImageLeaf` to `HKLM:\SOFTWARE\LCM\MacriumBaseline`.
- **Console Output**: Emits green formatted `[BASELINE]` blocks displaying both the image filename and its full path on disk.

### 2. `LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1`
- Displays `[BCR] Macrium Baseline Image: <filename>` and full path to stdout before review execution.
- Includes `BaselineImageFileName` in the returned review result object.

### 3. `LCM_Inventory/modules/LcmMacriumAtoms.psm1`
- Updates `Get-MacriumBaselineState` to inspect `MRMImagePath`, `MRMImageLeaf`, `actMImagePath`, and `actMImageLeaf`.
- Returns `ImagePath` and `ImageFileName` on the baseline telemetry PSCustomObject.

### 4. `LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1`
- In the unconditional baseline telemetry block, displays:
  `Baseline image file : <filename>` in green highlight.

### 5. `LCM_AI/.agents/LEARNED_ADVICE.md` (and hardlinked `.agents/LEARNED_ADVICE.md`)
- Added operational rule:
  > **Macrium Baseline Image Filename Logging & Chat Telemetry**: Whenever mounting, checking, reusing, or executing BCR against a Macrium Reflect baseline, the agent `MUST` explicitly state the mounted backup image filename (e.g. `0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-04-04.mrimgx`) and full path in the chat response. (Operator)

### 6. Automated Pester Tests
- Updated `LCM_Inventory/tests/MacriumBaselineAtoms.Tests.ps1` and `LCM_Inventory/tests/MacriumBcrReview.Tests.ps1` with regression tests for image filename logging and telemetry. All 16 tests pass in 1.12 seconds.

---

## 3. Live Verification Evidence

### A. Fast-Path Baseline Query
```powershell
pwsh -NoProfile -File LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1 -NoLaunchReview -Confirm:$false
```
**Output**:
```
2026-11-14 12:26:18.676 [INFO] Mounted candidate at F: (2026-11-13 21:37:17) matches today's completed backup (B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx). Reusing via fast-path.

[BASELINE] Reusing mounted Macrium baseline (F:): 0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
           Full Path: B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx

ImagePath     : B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
ImageFileName : 0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
MountedDrive  : F:
```

### B. Baseline Telemetry State Atom
```powershell
Import-Module './LCM_Inventory/modules/LcmMacriumAtoms.psm1'; Get-MacriumBaselineState
```
**Output**:
```
Plausible            : True
MountedDrive         : F:
VolumeLabel          : D4P3-WDB850-D
ImagePath            : B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
ImageFileName        : 0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
RegistryMRMImagePath : B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
RegistryMRMImageLeaf : 0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
```

### C. GoodMorning Read-Only Telemetry
```
[BASELINE] Macrium BCR baseline telemetry & physical mount
  Mounted baseline drive : F: (Volume: D4P3-WDB850-D)
  Baseline image file    : 0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-05-05.mrimgx
```

