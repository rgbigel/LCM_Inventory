# Walkthrough: BUG-299 - [BUG] Macrium Browse Image dialog detection times out while the dialog is visible

## 1. Executive Summary
Resolved the Macrium Browse Image dialog readiness timeout and Beyond Compare launch window detection timeouts in `Invoke-MacriumDailyBcrBaseline.ps1` and `Invoke-MacriumBcrReview.ps1`. Eliminated hardcoded 30-second deadlines in favor of configurable `$MountTimeoutSeconds`, added candidate process fallback to recognize dialogs on existing `ReflectBin` processes, and extended Beyond Compare launch window detection to 60 seconds.

## 2. Changes Made
1. **`LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1`**:
   - Replaced hardcoded 30s deadline in volume detach polling with `$MountTimeoutSeconds`.
   - Replaced hardcoded 30s deadline in Browse Image dialog polling with `$MountTimeoutSeconds`.
   - Added candidate process ID fallback to check all `ReflectBin` processes if no new PID was created.
   - Increased Beyond Compare window detection deadline from 15s to 60s.
   - Updated Version to 10.0.1 and Date to 2026-10-21.
2. **`LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1`**:
   - Added `[int]$MountTimeoutSeconds = 120` parameter.
   - Forwarded `MountTimeoutSeconds` to `Invoke-MacriumDailyBcrBaseline.ps1`.
   - Updated Version to 10.0.3 and Date to 2026-10-21.
3. **`LCM_Inventory/tests/MacriumBcrReview.Tests.ps1`**:
   - Added test block verifying elimination of 30-second deadlines and enforcement of `$MountTimeoutSeconds` and 60-second window wait.

## 3. Verification Evidence
1. **AST Validation:**
   - `Invoke-MacriumDailyBcrBaseline.ps1`: 0 syntax errors.
   - `Invoke-MacriumBcrReview.ps1`: 0 syntax errors.
   - `MacriumBcrReview.Tests.ps1`: 0 syntax errors.
2. **Pester Suite Execution:**
   - `MacriumBcrReview.Tests.ps1`: 10 passed, 0 failed.
   - `MacriumBaselineAtoms.Tests.ps1`: 3 passed, 0 failed.
