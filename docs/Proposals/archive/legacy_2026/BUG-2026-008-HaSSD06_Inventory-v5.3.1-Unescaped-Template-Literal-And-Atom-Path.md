---
Proposal-ID: BUG-2026-008
CR-ID: CR-2026-048
Scope: HaSSD06_Inventory
Version: 10.0.0
Affected-Repos: [HaSSD06_Inventory]
Status: In_Progress
Date: 2026-10-13
Author: rgbig
Target Scope: HaSSD06_Inventory / tools / Show-HaInventoryApp.ps1
Affected Version Range: 10.0.0
Impacted Repositories: [HaSSD06_Inventory]
Severity: High
---

# BUG-2026-008: Unescaped Template Literal and Stale Atom Path in Show-HaInventoryApp.ps1

## 1. Defect Description & Discovery Vector
When loading the generated Home Assistant Subsystem Inventory Explorer (`SHOW_HA_INVENTORY.html`), the user interface renders static metrics and tables but fails to respond to any button clicks (tab switching, theme toggle, column sorting, device grouping, search filtering, and drill-down modals are completely dead).

## 2. Root Cause Analysis
Two distinct defects in `HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1` caused this failure:
1. **Fatal JavaScript Syntax Error**:
   In `Show-HaInventoryApp.ps1` at line 1415, the print atom initialization callback attempted to return a JavaScript template literal inside PowerShell's double-quoted here-string (`$html = @" ... "@`):
   ```powershell
   return `${tabName}_Inventory_${Instance}.html`;
   ```
   PowerShell treats backticks (`` ` ``) as escape operators and stripped them, emitting raw invalid JavaScript into the HTML document:
   ```javascript
   return ${tabName}_Inventory_HaSSD06.html;
   ```
   The browser JavaScript parser threw `SyntaxError: Unexpected token '{'`, causing the entire `<script>` block to fail compilation. None of the global UI functions (`showTab`, `toggleTheme`, `filterTables`, `sortTable`, etc.) were declared, causing all button click handlers to fail.
2. **Stale Asset Path for Table Print Atom**:
   Line 108 referenced `$atomJsPath = Join-Path $workspaceRoot 'tools\assets\lcm-table-print-atom.js'`, but the asset resides at `LCM_Inventory\assets\lcm-table-print-atom.js`. As a result, `$atomJsContent` was empty.

## 3. Remediation Strategy
1. **Robust String Concatenation**: Replace the backtick template literal with standard JavaScript string concatenation (`return tabName + '_Inventory_${Instance}.html';`) to eliminate PowerShell escape collision.
2. **Multi-Candidate Asset Resolution**: Update `$atomJsPath` resolution to probe `LCM_Inventory\assets\lcm-table-print-atom.js`, `tools\assets\`, and local `assets\`.
3. **Defensive Initialization**: Wrap `LcmTablePrintAtom.init(...)` with `if (typeof LcmTablePrintAtom !== 'undefined')` to prevent future runtime failures if assets are missing.
4. **Regeneration & Verification**: Rebuild `SHOW_HA_INVENTORY.html` using `Show-HaInventoryApp.ps1 -NoLaunch`, verify JavaScript parsing with Node.js (0 syntax errors), and run `Test-RepoReadiness.ps1`.
