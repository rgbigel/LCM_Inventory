---
Target Scope: LCM
Affected Version Range: v6.2.0
Impacted Repositories:
  - Root (D:\Git_Repositories)
  - LCM_Inventory
---
# CRP-106-LCM-v6.2.0-Tool-Architecture-Consolidation

## 1. Description
This Change Request proposes consolidating the `.tools` global command hub into the `.lcm\tools` directory. By doing so, the architecture clearly delineates between:
- **internal**: Foundational mechanics and autonomous daemons.
- **hub**: Top-level interactive scripts (e.g., `Show-LCM.ps1`).
- **cmd**: Generated `.cmd` trampolines serving as the global bin directory.

## 2. Motivation
Currently, `tools` (recently migrated to `.tools`) sits loosely at the root. The LCM backend tools exist inside `.lcm\tools\internal`. The distinction between "internal" engine scripts and user-facing external hubs is highly advantageous for clear governance, but scattering them across root vs `.lcm` creates fragmentation. Consolidation unifies all tooling mechanisms under the `.lcm` namespace.

## 3. Implementation Steps
1. **Directory Restructure**:
   - Create `.lcm\tools\hub` and move `Show-LCM.ps1`, `Show-LCMRules.ps1`, `Show-Subsystems.ps1` from `.tools`.
   - Rename `.tools\Cmd` to `.lcm\tools\cmd`.
2. **Legacy Cleanup**:
   - Move `Invoke-BeyondCompareReview.ps1` and `Clear-BCReviewTemp.ps1` to `.lcm\tools\internal`.
   - Remove dead scripts (`RR.ps1`) from root.
3. **Engine Modifications**:
   - Update `Update-ToolCatalog.ps1` to output trampolines to `.lcm\tools\cmd`.
   - Update `Set-LcmSystemPath.ps1` to exclusively add `.lcm\tools\cmd` (and `.lcm\Cmd`) to the Machine PATH.
   - Refactor hardcoded `.tools` references globally across all `LCM_Inventory` and `.lcm` files.
4. **.gitignore Update**:
   - Scrub `.tools` exemptions and ensure `.lcm\tools\cmd` and `.lcm\tools\hub` are not improperly tracked (if intended to be tracked) or ignored.

## 4. Acceptance Criteria
- No remaining `.ps1` files at the workspace root.
- The `.tools` directory is entirely removed.
- Tool catalogs successfully regenerate directly into `.lcm\tools\cmd`.
- `Set-LcmSystemPath.ps1` sets correct global pathways without polluting user-level environments.

