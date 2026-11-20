# Walkthrough: BUG-389 - Push Convergence Test Uses Audited Version That Is Always Current

Module: docs/Proposals/389_BUG-Push-Convergence-Test-Uses-Audited-Version-That-Is/Walkthrough BUG-389.md  
Purpose: Walkthrough of BUG-389.  
Path: LCM_Inventory/docs/Proposals/389_BUG-Push-Convergence-Test-Uses-Audited-Version-That-Is/Walkthrough BUG-389.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Verified  
Date: 2026-11-20 16:22:49

---

## Path Taken (DOIT, operator option A 2026-11-20)

- `LCM_Inventory/modules/LCM_PushEligibility.psm1`: `Get-LCM_UnconvergedPushRepositories` holds every governed
  repository outside the core by default; the audited `CurrentLCMVersion` is no evidence (the audit stamps the
  shared baseline on every governed repository). The release record arrives with the first convergence CRP.
- `LCM_Inventory/tools/Invoke-LCM_Push.ps1`: nothing ahead is a clean no-op (exit 0; before: exception, which
  would fail a GoodNight -Push on a quiet day); the PUSH_EXECUTED log line takes the LCM version from
  `.agents/version.json` (before: a missing inventory key gave the fallback 10.0.0).
- `LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1`: the last remote push is the newest PUSH_EXECUTED line of
  `cm_activity.log`; HKLM `MRPushTimeStamp` only as fallback (a non-elevated push cannot write it; it stood at
  2026-11-06 although pushes ran on 2026-11-19 and 2026-11-20).
- `LCM_Inventory/tests/LCM_PushEligibility.Tests.ps1` 10.2.4: the held case expects both governed repositories
  held, also the one with an audited 10.8.4.
- One-time exception (Specification): line-ending correction everywhere, then the five held repositories pushed
  outside LCM on operator order.

## Test Evidence (2026-11-20 16:22:49)

| Check | Result |
|:---|:---|
| `Parser::ParseInput` module, push, GoodMorning, tests | 0 errors |
| `LCM_PushEligibility.Tests.ps1` | 15 passed |
| `Invoke-LCM_Push.ps1 -DryRun -NonInteractive` with nothing ahead | "nothing to push", exit 0 |
| `Invoke-LCM_GoodMorning.ps1 -WhatIf` | "Last remote push: 2026-11-20 16:13:59" (before: 2026-11-06) |
