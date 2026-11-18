# Walkthrough: BUG-302 - [BUG] New-WorkspaceProposal damages the yaml code fences of generated Specification.md

## 1. Executive Summary
Resolved backtick escaping bug in `New-WorkspaceProposal` (`ProposalManager.psm1`), added dedicated automated Pester regression tests, and repaired all 18 historical damaged `Specification.md` files across the workspace.

## 2. Changes Made
1. **`LCM_Inventory/modules/ProposalManager.psm1`**:
   - Added `$fence = '```'` before the template definition.
   - Replaced ```` ```yaml ```` with `${fence}yaml` and closing ```` ``` ```` with `${fence}`.
2. **`LCM_Inventory/tests/ProposalSpecificationFence.Tests.ps1`**:
   - Added regression test suite verifying AST tokens, `$fence` presence, and exact template expansion.
3. **Repaired Specification.md files (18 total)**:
   - `LCM_AI` (1): `CRP-270`
   - `LCM_Inventory` (15): `BUG-276`, `CRP-243`, `CRP-245`, `CRP-246`, `CRP-267`, `CRP-268`, `CRP-269`, `CRP-274`, `CRP-277`, `CRP-278`, `CRP-279`, `CRP-280`, `CRP-281`, `CRP-282`, `CRP-283`
   - `LCM_Shared` (1): `CRP-272`
   - `LCM_Supervision` (1): `CRP-273`

## 3. Verification Evidence
1. **AST Validation:**
   ```powershell
   [System.Management.Automation.Language.Parser]::ParseFile('D:\Git_Repositories\LCM_Inventory\modules\ProposalManager.psm1', [ref]$null, [ref]$errors)
   # Errors: 0
   ```
2. **Pester Suite Execution:**
   - `ProposalSpecificationFence.Tests.ps1`: 4 passed, 0 failed.
3. **Workspace Rescan:**
   - Total `Specification.md` files inspected: 113+
   - Remaining damaged files: 0
