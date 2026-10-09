# Implementation Plan: Proposal-077 (CR-2026-048 / BUG-2026-008)

## Overview
Fix JavaScript syntax error and stale asset path in `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1` causing total button unresponsive state in `SHOW_HA_INVENTORY.html`.

## Target Scope
- `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`
- `HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html` (regenerated artifact)

## Proposed Changes
1. **Show-HaInventoryApp.ps1**:
   - Update header version to `5.3.2`, date `2026-09-06`.
   - Update `$atomJsPath` resolution using candidate list including `LCM_Inventory\assets\lcm-table-print-atom.js`.
   - Change line 1415 from template literal to clean string concatenation: `return tabName + '_Inventory_${Instance}.html';`.
   - Wrap `LcmTablePrintAtom.init` call in defensive guard: `if (typeof LcmTablePrintAtom !== 'undefined')`.
2. **Regeneration & Verification**:
   - Run `pwsh -File HaSSD06_Inventory\tools\Show-HaInventoryApp.ps1 -NoLaunch` to regenerate `SHOW_HA_INVENTORY.html`.
   - Validate script parsing using Node.js script compilation.
   - Run `HaSSD06_Inventory\tools\Test-RepoReadiness.ps1`.
