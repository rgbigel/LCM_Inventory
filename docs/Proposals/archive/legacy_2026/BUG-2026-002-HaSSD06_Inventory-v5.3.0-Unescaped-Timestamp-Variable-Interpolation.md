---
Proposal-ID: BUG-2026-002
CR-ID: CR-2026-038
Scope: HaSSD06_Inventory
Version: v5.3.0
Affected-Repos: [HaSSD06_Inventory]
Status: Suggested
Date: 2026-08-30
Author: rgbig
Target Scope: HaSSD06_Inventory / tools / Show-HaInventoryApp.ps1
Affected Version Range: v5.3.0
Impacted Repositories: [HaSSD06_Inventory]
---

# BUG-2026-002: Unescaped `$timestamp` Variable Interpolation in Show-HaInventoryApp.ps1

## 1. Defect Description & Discovery Vector
During the execution of `Update-HaInventory.ps1` (which calls `Show-HaInventoryApp.ps1 -NoLaunch` to rebuild the HTML viewer), PowerShell `Set-StrictMode -Version Latest` threw the following runtime error:
```
The variable '$timestamp' cannot be retrieved because it has not been set.
```
This aborted the automated generation of the HTML viewer and triggered an error block in `Update-HaInventory.ps1`.

## 2. Root Cause Analysis
In `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1` at line 1416, the print atom configuration object contained:
```javascript
getDate: () => {
    return '$timestamp';
}
```
Inside the PowerShell double-quoted here-string (`$html = @" ... "@`), PowerShell evaluated `$timestamp` as an active variable rather than a string literal or bound timestamp parameter. Because only `$genTime` was defined at the script header, PowerShell StrictMode threw a fatal uninitialized variable exception.

## 3. Remediation Strategy
1. Replace `$timestamp` with `$genTime` (or escape as `` `$timestamp ``).
2. Validate syntax with `Test-RepoReadiness.ps1` in `HaSSD06_Inventory`.
3. Verify that `Update-HaInventory.ps1` completes with 0 errors and generates `SHOW_HA_INVENTORY.html`.
