# Implementation Plan: CRP-328

## 1. Overview
Enhance Macrium baseline mounting and inspection tools (`Invoke-MacriumDailyBcrBaseline.ps1`, `Invoke-MacriumBcrReview.ps1`, `LcmMacriumAtoms.psm1`, and `Invoke-LCM_GoodMorning.ps1`) to record, log, and display the exact `.mrimgx` image filename and full path, and add an operational chat disclosure rule to `LEARNED_ADVICE.md`.

## 2. File Changes & Responsibilities
1. **`LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1`**:
   - Save `MRMImagePath` and `MRMImageLeaf` to registry (`HKLM:\SOFTWARE\LCM\MacriumBaseline`) on fresh mount.
   - Resolve `$resolvedImagePath` and `$resolvedImageLeaf` on fast-path reuse and populate them on the output PSCustomObject.
   - Format console output (`Write-Host`) prominently displaying the image filename and path.
2. **`LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1`**:
   - Display `[BCR] Baseline Image File: <filename>` and path.
3. **`LCM_Inventory/modules/LcmMacriumAtoms.psm1`**:
   - In `Get-MacriumBaselineState`: inspect `MRMImagePath` / `MRMImageLeaf` and return `ImagePath` and `ImageFileName` properties.
4. **`LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1`**:
   - In baseline telemetry, display `Baseline image file : <filename>`.
5. **`LCM_AI/.agents/LEARNED_ADVICE.md`**:
   - Add the operational rule requiring the agent to display the Macrium Reflect baseline image filename in chat whenever baseline operations are executed or reported.
6. **Tests**:
   - Update `LCM_Inventory/tests/MacriumBaselineAtoms.Tests.ps1` and `LCM_Inventory/tests/MacriumBcrReview.Tests.ps1` to cover filename logging and telemetry.

## 3. Verification & Safety
- Run Pester tests.
- Execute read-only verification of `Get-MacriumBaselineState` and `Invoke-MacriumDailyBcrBaseline.ps1 -NoLaunchReview`.

