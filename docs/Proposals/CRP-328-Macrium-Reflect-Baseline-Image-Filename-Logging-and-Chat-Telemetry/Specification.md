# Specification: Macrium Reflect Baseline Image Filename Logging and Chat Telemetry

**Document Information**
- **Proposal ID**: CRP-328
- **Title**: Macrium Reflect Baseline Image Filename Logging and Chat Telemetry
- **Author**: Rolf & Antigravity
- **Date**: 2026-11-14
- **Status**: In Progress
- **Scope**: `LCM_Inventory` (Macrium Baseline, BCR Review, Baseline Telemetry Atoms, GoodMorning, Learned Advice)
- **Lifecycle Mode**: DOIT (Autonomous Velocity)

---

## 1. Problem Statement & Motivation
When a baseline is mounted with Macrium Reflect (or reused via fast-path), operators and AI agents need unambiguous visibility into the exact `.mrimgx` backup image file that constitutes the baseline. Previously:
1. `Invoke-MacriumDailyBcrBaseline.ps1` only recorded `MRMdrive` and `MRMTimeStamp` in the registry and returned `ImagePath = ''` upon fast-path candidate reuse.
2. The exact backup image filename (e.g. `0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-04-04.mrimgx`) was not prominently surfaced in console output or GoodMorning telemetry.
3. Chat interactions lacked a durable rule mandating that the agent explicitly state the mounted backup image filename whenever reporting on or interacting with the Macrium baseline.

---

## 2. Requirements & Goals

### Functional Requirements
- **FR-01 (Registry Telemetry)**: Store `MRMImagePath` (full path) and `MRMImageLeaf` (filename) in `HKLM:\SOFTWARE\LCM\MacriumBaseline` whenever a fresh Macrium image is mounted, and mirror active reuse values (`actMImagePath`, `actMImageLeaf`).
- **FR-02 (Fast-Path Image Resolution)**: On fast-path baseline reuse, resolve the `.mrimgx` image path (from same-day completed image metadata or registry `MRMImagePath`) and populate `ImagePath` and `ImageLeaf` in the returned object rather than returning an empty string.
- **FR-03 (Console & Log Prominence)**: Prominently print the image filename and full path to stdout with green highlight in `Invoke-MacriumDailyBcrBaseline.ps1` and `Invoke-MacriumBcrReview.ps1` (e.g. `[BASELINE] Mounted Macrium baseline image: <filename>`).
- **FR-04 (Atom Telemetry)**: Update `Get-MacriumBaselineState` in `LcmMacriumAtoms.psm1` to read and return `ImagePath` and `ImageLeaf`.
- **FR-05 (GoodMorning Telemetry)**: Update `Invoke-LCM_GoodMorning.ps1` baseline telemetry to output the baseline image file name alongside drive letter and volume label.
- **FR-06 (Agent Chat Transparency)**: Record an operational invariant in `LEARNED_ADVICE.md` requiring AI agents to explicitly output the mounted Macrium baseline image file name in chat responses whenever baseline or BCR operations occur.

### Non-Goals
- Altering the underlying Macrium Reflect backup schedule, drive letter selection, or AHK automation dialog logic.
- Modifying Beyond Compare 5 profile configuration (`_LCM`).

---

## 3. Technical Design

### A. `Invoke-MacriumDailyBcrBaseline.ps1`
1. When mounting an image afresh:
   - Call `Set-LcmRegistryValue` for `MRMImagePath` and `actMImagePath` with `$completedImage.ImagePath`.
   - Call `Set-LcmRegistryValue` for `MRMImageLeaf` and `actMImageLeaf` with `Split-Path $completedImage.ImagePath -Leaf`.
   - Output to host:
     ```powershell
     Write-Host "`n[BASELINE] Mounted Macrium baseline image: $(Split-Path $completedImage.ImagePath -Leaf)" -ForegroundColor Green
     Write-Host "           Full Path: $($completedImage.ImagePath)" -ForegroundColor Green
     Write-Host "           Drive    : $($receipt.MountedDrive)`n" -ForegroundColor Green
     ```
2. When reusing an existing baseline candidate:
   - Resolve `$resolvedImagePath` from `$completedToday.ImagePath` or registry `MRMImagePath`.
   - Populate `ImagePath = $resolvedImagePath` and `ImageLeaf = (Split-Path $resolvedImagePath -Leaf)` on the returned PSCustomObject.
   - Output to host:
     ```powershell
     Write-Host "`n[BASELINE] Reusing mounted Macrium baseline ($($mountedBaseline.MountedDrive)): $resolvedLeaf" -ForegroundColor Green
     if ($resolvedImagePath) {
       Write-Host "           Full Path: $resolvedImagePath`n" -ForegroundColor Green
     }
     ```

### B. `Invoke-MacriumBcrReview.ps1`
- When displaying review setup:
  ```powershell
  if (-not [string]::IsNullOrWhiteSpace($baselineImage)) {
    Write-Host "[BCR] Baseline Image File: $(Split-Path $baselineImage -Leaf)" -ForegroundColor Green
    Write-Host "      Baseline Full Path : $baselineImage" -ForegroundColor Green
  }
  ```

### C. `LcmMacriumAtoms.psm1` & `Invoke-LCM_GoodMorning.ps1`
- `Get-MacriumBaselineState` queries `MRMImagePath`, `actMImagePath`, `MRMImageLeaf`, and `actMImageLeaf` and includes `ImagePath` and `ImageLeaf` in the returned state object.
- `Invoke-LCM_GoodMorning.ps1` displays `Baseline image file    : <ImageLeaf>` if present.

### D. Durable Agent Guidance (`LEARNED_ADVICE.md`)
- Add operational rule under BCR/Baseline section:
  > **Macrium Baseline Chat Telemetry**: Whenever mounting, checking, or executing BCR against a Macrium Reflect baseline, the agent MUST explicitly state the baseline backup image filename (e.g. `0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-04-04.mrimgx`) in the chat response.

---

## 4. Verification Plan
1. **Automated Testing**:
   - Update `MacriumBaselineAtoms.Tests.ps1` to assert `Get-MacriumBaselineState` captures `ImagePath` and `ImageLeaf` from registry telemetry.
   - Update `MacriumBcrReview.Tests.ps1` to assert fast-path baseline returns non-empty `ImagePath`.
   - Run Pester test suite to verify 100% pass rate.
2. **Live Execution Test**:
   - Run `Invoke-MacriumDailyBcrBaseline.ps1 -NoLaunchReview` and verify console output includes the image filename and full path.
   - Inspect registry `HKLM:\SOFTWARE\LCM\MacriumBaseline` to confirm `MRMImagePath` and `MRMImageLeaf`.

