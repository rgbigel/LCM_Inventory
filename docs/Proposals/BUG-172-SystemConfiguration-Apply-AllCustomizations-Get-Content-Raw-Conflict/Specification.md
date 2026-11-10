# Defect Report & Specification: BUG-172

```yaml
BUG-ID: BUG-172
Title: Remediate Get-Content Parameter Conflict in Apply-AllCustomizations
Scope: SystemConfiguration / Source / Apply-AllCustomizations.ps1
Baseline-Version: 10.2.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-10-13
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
Impacted-Repositories:
  - SystemConfiguration
  - .lcm
```

---

## 1. Defect Description & Runtime Telemetry

During execution of the **System Customizations Master Applicator** ([`Apply-AllCustomizations.ps1`](file:///D:/Git_Repositories/SystemConfiguration/Source/Apply-AllCustomizations.ps1)), Step 2 (`@02-Set_the_date_and_time_format_(ADM_systemwide).ps1`) threw an unhandled terminating error:

```
[StepBegin] @02-Set_the_date_and_time_format_(ADM_systemwide).ps1
-> [@02-Set_the_date_and_time_format_(ADM_systemwide).ps1]
Get-Content: D:\Git_Repositories\SystemConfiguration\Source\Apply-AllCustomizations.ps1:236
Line |
 236 |   $fileHead = Get-Content -LiteralPath $Path -TotalCount 40 -Raw -ErrorAction SilentlyContinue
     |               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | The 'Raw' and 'TotalCount' parameters cannot be specified in the same command.
```

### Root Cause Analysis:
In PowerShell `Get-Content`:
- The `-Raw` parameter reads the entire file as a single multiline string.
- The `-TotalCount` (or `-Head`) parameter reads a specified number of lines from the top of the file as an array of strings.
- Combining `-Raw` and `-TotalCount` is invalid and forbidden by the PowerShell engine parameter binder.
- Because `Apply-AllCustomizations.ps1` runs under `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`, parameter binding errors terminate execution immediately.
- The same defect existed in lines 222 (`.bat`), 229 (`.cmd`), and 236 (`.ps1`). Latent instances were also identified in `LCM_Inventory/tools/Update-ToolCatalog.ps1` (line 981) and `LCM_Inventory/tools/Flush-LcmLegacyLogs.ps1` (line 78).

---

## 2. Remediation Strategy

1. Replace `Get-Content -LiteralPath $Path -TotalCount <N> -Raw` with `(Get-Content -LiteralPath $Path -TotalCount <N> -ErrorAction SilentlyContinue) -join "`n"`.
2. This safely reads the top `<N>` lines and joins them into a single string for downstream regex `-match` operations (`$t`, `$ShowAll`).
3. Remediate latent occurrences in `LCM_Inventory/tools/Update-ToolCatalog.ps1` and `LCM_Inventory/tools/Flush-LcmLegacyLogs.ps1`.
