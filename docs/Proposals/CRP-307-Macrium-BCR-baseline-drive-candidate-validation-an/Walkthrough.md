# Walkthrough: BUG-307 - Macrium BCR baseline drive candidate validation, registry timestamp tracking, and BCR fast-path

```yaml
CRP-ID: BUG-307
Title: Macrium BCR baseline drive candidate validation and registry timestamp tracking
Scope: LCM_Inventory
Baseline-Version: 10.2.2
Author: rgbig
Date: 2026-11-06 16:51:55
Status: In_Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
App-ID: None
```

---

## 1. Executive Summary
Intake, architectural decisions, and verification records for **BUG-307**.
Addresses the automated BCR baseline preparation failure when drive `F:` is absent, replaces `-ReuseMountedBaseline` with an intuitive `-NewBaseline` switch (defaulting to `$false`), introduces a configurable candidate drives list (`CandidateDrives = @('F','G','H','I')`), tracks system registry timestamp telemetry (`MRMTimeStamp`, `MRMdrive`, `ActMTimeStamp`, `actMdrive`, `MRPushTimeStamp`), plausibility-tests candidate volumes against internal log freshness (`data\logs\lcm-internal`), aligns GoodMorning to single-authority delegation, and provides an instant fast-path for BCR review reuse.

---

## 2. Summary of Implemented Changes

### 1. `Invoke-MacriumDailyBcrBaseline.ps1` (v10.0.3)
- **Candidate Drive List Parameter**: Replaced hardcoded drive array with `[object]$CandidateDrives = @('F', 'G', 'H', 'I')`, paired with helper `Normalize-LcmCandidateDrives` supporting strings (`"F;G;H;I"`, `"F, G, H"`) and arrays, enforcing length $\ge 1$.
- **Inverted Switch Semantics (`-NewBaseline`)**: Replaced `-ReuseMountedBaseline` with `[switch]$NewBaseline`. When `$false`, reuses existing valid baseline or auto-mounts if absent. When `$true`, explicitly dismounts existing mount and mounts today's fresh Macrium image.
- **Registry Telemetry Helpers**: Added `Set-LcmRegistryValue` and `Get-LcmRegistryValue` targeting `HKLM:\SOFTWARE\LCM\MacriumBaseline\` and `HKLM:\SOFTWARE\LCM\`. Handled `$WhatIfPreference` cleanly.
- **Internal Log Freshness Plausibility Check**: Implemented `Find-MountedMacriumBaselineCandidates` inspecting `[x:]\Git_Repositories\LCM_Inventory\data\logs\lcm-internal` for the newest log timestamp, warning if drift against `MRMTimeStamp` exceeds 1 day.
- **Instant BCR Fast-Path**: When candidate drive is already mounted and no newer backup exists than `MRMTimeStamp`, reuses the mounted baseline in $< 500$ ms without remounting or UAC elevation.
- **Post-Push Sync Discretion**: When `MRPushTimeStamp` is newer than `MRMTimeStamp`, issues a non-blocking operator notice that local pushes have occurred since baseline was taken.

### 2. `Invoke-MacriumBcrReview.ps1` (v10.0.4)
- Added `-NewBaseline` and `-CandidateDrives` parameters and forwarded to `Invoke-MacriumDailyBcrBaseline.ps1`.
- Cleaned up call site parameters.

### 3. `Mount-MacriumLatestBaseline.ps1` (v10.0.1)
- Added `-CandidateDrives` parameter and forwarded `-NewBaseline -CandidateDrives $CandidateDrives -Confirm:$false`.

### 4. `Invoke-LCM_Push.ps1`
- Persists `MRPushTimeStamp` to `HKLM:\SOFTWARE\LCM\` upon successful multi-repository push.
- Displays last push timestamp in pre-flight banner.

### 5. `Invoke-LCM_GoodMorning.ps1`
- Alerts operator if `MRPushTimeStamp` indicates remote push is overdue ($\ge 3$ days).
- Retained `Invoke-MacriumDailyBcrBaseline.ps1` as the single authoritative routine.

### 6. `tests/MacriumBcrReview.Tests.ps1`
- Added comprehensive unit and regression assertions covering `CandidateDrives`, `Normalize-LcmCandidateDrives`, `NewBaseline`, registry keys, and fast-path.

---

## 3. Verification & Evidence

### 1. AST Syntax Validation (`RULE-PS-021`)
- Verified all touched PowerShell files with `[System.Management.Automation.Language.Parser]::ParseFile()`:
  - `tools/Clear-BCReviewTemp.ps1`: 0 errors
  - `tools/Invoke-MacriumDailyBcrBaseline.ps1`: 0 errors
  - `tools/Invoke-MacriumBcrReview.ps1`: 0 errors
  - `tools/Mount-MacriumLatestBaseline.ps1`: 0 errors
  - `tools/Invoke-LCM_Push.ps1`: 0 errors
  - `tools/Invoke-LCM_GoodMorning.ps1`: 0 errors
  - `tests/MacriumBcrReview.Tests.ps1`: 0 errors

### 2. Unit & Regression Tests (Pester v6.2.0)
- `tests/MacriumBcrReview.Tests.ps1`: 11/11 tests passed in 836ms.
- `tests/MacriumBaselineAtoms.Tests.ps1`: 3/3 tests passed in 650ms.
- `tests/ProposalManager.Tests.ps1`: 21/21 tests passed.

### 3. Execution Dry-Run (`-WhatIf`)
- **Fast-path detection test**:
  ```powershell
  Invoke-MacriumDailyBcrBaseline.ps1 -WhatIf
  ```
  Result:
  `[INFO] WhatIf: would reuse writable F: Macrium baseline for 'CRP-253' via fast-path.`
  Correctly resolved candidate drive `F:`, skipped redundant mounting, and completed cleanly.
- **Candidate drives exclusion & fallback test**:
  ```powershell
  Invoke-MacriumDailyBcrBaseline.ps1 -WhatIf -CandidateDrives 'G;H;I'
  ```
  Result:
  `[WARN] No candidate volume matching 'D4P3-WDB850-D' found in drives (G, H, I). Triggering ForceNewBackup...`
  `[INFO] WhatIf: would start the configured Macrium backup definition and wait for today's completed Macrium report.`
  Demonstrates that when candidate drive list excludes the mounted volume, it automatically falls back to forcing a new backup as specified.

### 4. Gate 2 BCR Launch & Port 9876 Foreground Dispatch
- **Issue Discovered**: Direct `Start-Process` invocations from sandboxed or background agent runspaces launch GUI processes into isolated background window contexts rather than the interactive user desktop, preventing the Beyond Compare window from displaying in the foreground.
- **Resolution**:
  - Implemented `Start-LcmBcrReviewProcess` and `Set-LcmReviewForeground` in [Invoke-MacriumDailyBcrBaseline.ps1](file:///D:/Git_Repositories/LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1).
  - Routed Beyond Compare launch through the local LCM Desktop Daemon (`http://127.0.0.1:9876/open`) with `foreground: true` and fallback activation via `http://127.0.0.1:9876/foreground`.
  - Also resolved Delphi VCL top-level window handle resolution via Win32 `EnumWindows` matching `_LCM - Folder Compare`.
- **BCR Review Launched**:
  - Command: `bcr BUG-307`
  - Output:
    - `[INFO] Dispatched Beyond Compare in foreground mode via LCM Desktop Daemon (Port 9876).`
    - `[INFO] Activated Beyond Compare foreground review window via port 9876 daemon.`
    - `[INFO] Reused writable F: Macrium baseline for 'BUG-307' via fast-path.`
  - Lifecycle state: `BUG-307` is active in `in_review`.
