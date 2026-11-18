# Implementation Plan: CRP-301 - Relocate docs content into LCM_AI docs: correct folder references, shift versions to 10.0.0, update LCM_* references

## 1. Executive Summary & Problem Context
The operator copied files from `D:\Git_Repositories\docs` into `LCM_AI\docs`. In preparation for `D:\Git_Repositories\docs` becoming a junction target pointing to `LCM_AI\docs`, all copied files must have their internal folder paths corrected to `LCM_AI\docs\...`, version declarations shifted to 10.0.0, and existing references in all `LCM_*` repositories updated.

## 2. Gate 0 Traceability
- **Clause 1 (Hash Verification):** Confirm 100% SHA256 match between original files in `D:\Git_Repositories\docs` and copies in `LCM_AI\docs` prior to modification.
- **Clause 2 (File Header & Content Correction):** In `LCM_AI\docs\LCM_Subsystem_Architecture.md` and `Parent_Workspace_Solution.md`, update module/file path declarations to `LCM_AI/docs/...` and version declarations to 10.0.0.
- **Clause 3 (Rules & Export Sync):** In `LCM_AI\.agents\rules\MethodEfficiencyPolicy.md`, update `docs/Requisites/external-tools.json` to `LCM_AI/docs/Requisites/external-tools.json`, and run `Export-LCMRules.ps1`.
- **Clause 4 (Inventory Tooling Updates):** Update `Set-GitRoot.ps1`, `Search-Everything.ps1`, `Test-ExternalTools.ps1`, and `Show-WorkspaceReadiness.ps1` to resolve Requisites from `LCM_AI\docs\Requisites\external-tools.json` with fallback to `docs\Requisites\external-tools.json`.

## 3. Proposed Changes
### Component 1: Hash Comparison & Content Normalization
- Files:
  - `LCM_AI/docs/LCM_Subsystem_Architecture.md`: Path, Module, Version (10.0.0), Date (2026-10-21).
  - `LCM_AI/docs/Parent_Workspace_Solution.md`: Version (V10.0.0), related architecture document link to `LCM_AI/docs/`.
  - `LCM_AI/docs/Requisites/external-tools.json`: Verified JSON schema and content.
  - `LCM_AI/docs/Requisites/README.md`: Verified relative markdown links.

### Component 2: Cross-Repository Reference Updates
- Files:
  - `LCM_AI/.agents/rules/MethodEfficiencyPolicy.md`
  - `LCM_AI/docs/LCM_Rules.txt`, `LCM_Rules_Gemini_Export.md`, `LCM_Rules_Gemini_Export.txt`
  - `LCM_Inventory/tools/Set-GitRoot.ps1`
  - `LCM_Inventory/tools/Search-Everything.ps1`
  - `LCM_Inventory/tools/Test-ExternalTools.ps1`
  - `LCM_Inventory/tools/Show-WorkspaceReadiness.ps1`

## 4. Verification Plan
- SHA256 hash match verification before editing.
- AST syntax validation across all modified `.ps1` files.
- Automated Pester suite verification (`MacriumBaselineAtoms.Tests.ps1`, `MacriumBcrReview.Tests.ps1`, `ProposalSpecificationFence.Tests.ps1`).
- Ripgrep verification of old vs new paths across `LCM_*`.
- Beyond Compare visual review (`BCR 301`).
