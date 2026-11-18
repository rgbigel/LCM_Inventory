# Walkthrough: BUG-311

```yaml
CRP-ID: BUG-311
Title: [BUG] Repair Macrium Daily Baseline Selection, BCompare Non-Interference, and Direct Intent Mapping
Status: Verified
Author: Rolf, LCM_AI Engine
Date: 2026-11-09 17:20:00
```

---

## Verification Results

### 1. Unit Test Suite (Pester v6.2.0)
```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path d:\Git_Repositories\LCM_Inventory\tests\MacriumBcrReview.Tests.ps1, d:\Git_Repositories\LCM_Inventory\tests\LcmMacriumAtoms.Tests.ps1 -Output Detailed"
```
Output:
- `MacriumBcrReview.Tests.ps1`: 11 Passed, 0 Failed
- `LcmMacriumAtoms.Tests.ps1`: 5 Passed, 0 Failed
- Total: 16 Passed, 0 Failed (100% clean)

### 2. Candidate Selection Currency Test
```powershell
pwsh -NoProfile -Command '$WhatIfPreference = $true; & d:\Git_Repositories\LCM_Inventory\tools\Invoke-MacriumDailyBcrBaseline.ps1 -ReviewScope BUG-311'
```
Observed Output:
```
[INFO] Found today's completed Macrium image: B:\Backups\D4P3+4-WDB850-AD\C425281FE84743F1-@B_D4P3+4-WDB850-AD-09-09.mrimgx
       Mounted baseline at H: is stale (2026-11-07 16:29:47). Refreshing baseline to today's image...
WhatIf: would mount 'B:\Backups\D4P3+4-WDB850-AD\C425281FE84743F1-@B_D4P3+4-WDB850-AD-09-09.mrimgx' at a Macrium-selected F:-I: drive and launch _LCM for 'BUG-311'.
```

### 3. Decoupled Backup Generation & Mount Delegation Test
```powershell
pwsh -NoProfile -Command '$WhatIfPreference = $true; & d:\Git_Repositories\LCM_Inventory\tools\Start-MacriumDailyBackup.ps1 -Mount -ReviewScope BUG-311'
```
Observed Output:
```
[INFO] A completed Macrium backup already exists for today (2026-11-09):
       Image: B:\Backups\D4P3+4-WDB850-AD\C425281FE84743F1-@B_D4P3+4-WDB850-AD-09-09.mrimgx
       Completed: 2026-11-09 09:32:23
[INFO] WhatIf: would set registry HKLM:\SOFTWARE\LCM\MacriumBaseline\MRMTimeStamp = '2026-11-09 09:32:23'
[INFO] Delegating to baseline mounting atom (-Mount specified)...
[INFO] -NewBaseline specified. Dismounting any existing baseline in candidate drives (F, G, H, I)...
[INFO] WhatIf: would mount 'B:\Backups\D4P3+4-WDB850-AD\C425281FE84743F1-@B_D4P3+4-WDB850-AD-09-09.mrimgx' at a Macrium-selected F:-I: drive and launch _LCM for 'BUG-311'.
```

### 4. General Quality Readiness Gate (Step 1/2)
```powershell
pwsh -NoProfile -File d:\Git_Repositories\LCM_Inventory\tools\Test-GeneralReadiness.ps1 -RepositoryPath d:\Git_Repositories\LCM_Inventory
pwsh -NoProfile -File d:\Git_Repositories\LCM_Inventory\tools\Test-GeneralReadiness.ps1 -RepositoryPath d:\Git_Repositories\LCM_AI
```
Results:
- Both repositories passed 6/6 gates clean (188 files clean, AST syntax clean, elevated immutability clean).
