# Implementation Plan: BUG-311

```yaml
CRP-ID: BUG-311
Title: [BUG] Repair Macrium Daily Baseline Selection, BCompare Non-Interference, and Direct Intent Mapping
Status: Verified
Author: Rolf, LCM_AI Engine
Date: 2026-11-09 17:20:00
```

---

## Plan Steps

- [x] Step 1: Codify governance rules (`RULE-EFF-009`, `RULE-REV-012`, `RULE-LCM-017`) in `LCM_AI/.agents/rules/` and synchronize cross-references.
- [x] Step 2: Implement direct operational intent mapping catalog in `LCM_Inventory/config/tool_intents.json`.
- [x] Step 3: Repair `Invoke-MacriumDailyBcrBaseline.ps1`:
  - Upfront `Get-CompletedTodayImage` check.
  - Detect stale candidate drives when a newer image exists today and refresh baseline.
  - Eliminate destructive BCompare process termination.
  - Eliminate fatal single-window assertions (`Count -gt 1` / `Count -ne 1`).
  - Short-circuit `-NewBaseline` under `$WhatIfPreference`.
- [x] Step 4: Extract Macrium backup generation into dedicated atom `tools/Start-MacriumDailyBackup.ps1`:
  - Add `-Mount` switch delegating directly to `Mount-MacriumLatestBaseline.ps1`.
  - Carry over LCM baseline registry telemetry (`MRMTimeStamp`).
  - Add batch trampoline `Cmd/StartMacriumDailyBackup.cmd`.
- [x] Step 5: Decouple backup production from `Invoke-LCM_GoodMorning.ps1` (remove `-StartBackupIfMissing`).
- [x] Step 6: Verify unit tests across `MacriumBcrReview.Tests.ps1` and `LcmMacriumAtoms.Tests.ps1` (16/16 passing).
- [x] Step 7: Test candidate selection and backup generation with `-Mount` under `-WhatIf`.
- [x] Step 8: Verify general LCM quality readiness gates across repositories (6/6 gates passing).
