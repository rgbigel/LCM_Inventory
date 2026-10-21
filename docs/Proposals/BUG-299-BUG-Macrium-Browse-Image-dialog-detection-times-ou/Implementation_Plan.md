# Implementation Plan: BUG-299 - [BUG] Macrium Browse Image dialog detection times out while the dialog is visible

## 1. Executive Summary & Problem Context
During Macrium baseline preparation and BCR review, `Invoke-MacriumDailyBcrBaseline.ps1` hardcoded a 30-second timeout for the Browse Image dialog readiness loop and for detach polling. In addition, dialog polling filtered strictly by `Where-Object { $_.Id -notin $existingReflectBinIds }`, failing to locate the dialog if it opened within an existing `ReflectBin` process. Furthermore, Beyond Compare launch window detection timed out after only 15 seconds.

## 2. Gate 0 Traceability
- **Clause 1 (Dialog deadline flexibility):** Bind Macrium Browse Image dialog and detach deadlines to `$MountTimeoutSeconds` (allowing user-configured durations, e.g. 120s to 1800s).
- **Clause 2 (Dialog detection robustness):** Add fallback to all `ReflectBin` processes if no new process ID is found, ensuring dialogs attached to an existing process are recognized.
- **Clause 3 (BC window detection extension):** Increase Beyond Compare 5 window detection deadline from 15s to 60s.
- **Clause 4 (Wrapper parameter forwarding):** Add `MountTimeoutSeconds` parameter to `Invoke-MacriumBcrReview.ps1` and forward to `Invoke-MacriumDailyBcrBaseline.ps1`.

## 3. Proposed Changes
### Component 1: Daily Baseline Tool Correction
- File: `LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1`
- Use `$MountTimeoutSeconds` for detach and Browse Image dialog readiness deadlines.
- Check `$candidateProcessIds` with fallback to existing `ReflectBin` PIDs.
- Increase Beyond Compare launch detection timeout to 60 seconds.

### Component 2: Macrium BCR Review Wrapper Forwarding
- File: `LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1`
- Add `-MountTimeoutSeconds` parameter (default 120) and pass to `$baselineArgs`.

### Component 3: Regression Test Suite
- File: `LCM_Inventory/tests/MacriumBcrReview.Tests.ps1`
- Add test assertion verifying that hardcoded 30s timeouts are eliminated and `$MountTimeoutSeconds` / 60s limits are enforced.

## 4. Verification Plan
- AST parse validation across all modified tools and tests.
- Pester execution of `MacriumBcrReview.Tests.ps1` and `MacriumBaselineAtoms.Tests.ps1`.
