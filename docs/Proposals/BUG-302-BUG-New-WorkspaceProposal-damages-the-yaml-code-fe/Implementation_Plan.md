# Implementation Plan: BUG-302 - [BUG] New-WorkspaceProposal damages the yaml code fences of generated Specification.md

## 1. Executive Summary & Problem Context
In `LCM_Inventory/modules/ProposalManager.psm1`, `New-WorkspaceProposal` generated `Specification.md` templates inside an expandable here-string (`@"..."@`). Because backticks are escape characters in PowerShell expandable here-strings, lines 218 and 230 evaluated ` ```yaml ` to `` `yaml `` and ` ``` ` to `` ` ``, corrupting the YAML frontmatter in all generated proposal specifications.

## 2. Gate 0 Traceability
- **Clause 1 (Template correction):** In `ProposalManager.psm1`, define `$fence = '```'` prior to the template string and expand `${fence}yaml` / `${fence}`.
- **Clause 2 (Regression test):** Deploy `ProposalSpecificationFence.Tests.ps1` to assert that here-string tokens do not strip backticks, `$fence` is used, and expanded output contains intact YAML code fences.
- **Clause 3 (Repair damaged specifications):** Repair the 18 identified damaged `Specification.md` files across `LCM_AI`, `LCM_Inventory`, `LCM_Shared`, and `LCM_Supervision`.

## 3. Proposed Changes
### Component 1: ProposalManager Template Correction
- File: `LCM_Inventory/modules/ProposalManager.psm1`
- Add `$fence = '```'` and use `${fence}yaml` and `${fence}`.

### Component 2: Automated Regression Test
- File: `LCM_Inventory/tests/ProposalSpecificationFence.Tests.ps1`
- 4 Pester v5 tests validating template structure, token absence of escape patterns, variable definition, and expansion behavior.

### Component 3: Existing Damaged Files Repair
- 18 files repaired by replacing single-backtick fences with triple-backtick fences.

## 4. Verification Plan
- AST parse validation (`[System.Management.Automation.Language.Parser]::ParseFile`) across modified files.
- Pester execution: `ProposalSpecificationFence.Tests.ps1` (all pass).
- Full workspace rescan of `docs/Proposals/**/Specification.md` confirming 0 damaged files remain.
