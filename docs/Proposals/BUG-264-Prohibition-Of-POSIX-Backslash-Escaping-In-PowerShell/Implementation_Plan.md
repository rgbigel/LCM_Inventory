# Implementation Plan - BUG-264: Prohibition of POSIX Backslash Escaping in PowerShell

## User Review Required

> [!IMPORTANT]
> This plan executes immediate triage and resolution of the PowerShell backslash escaping gap and transcript extraction bug under DOIT mode, halting at Gate 2 BCR.

- **Proposed Changes**:
  - `LCM_AI/.agents/rules/PowerShellRules.md`: Add `no-posix-backslash-escapes: forbidden`.
  - `LCM_AI/.agents/rules/PowerShellStandardsPolicy.md`: Add `RULE-PS-022`.
  - `LCM_AI/docs/LCM-Rules-Cross-Reference.md`: Update rule matrix table.
  - `AGENTS.md`: Update quick-reference table.
  - `D:\OneDrive\cmd\Export-AntigravityExtractor.py`: Remove defective `text.startswith("")` guard.
  - `LCM_Inventory/tools/Update-Gemini.ps1`: Run export synchronization.
- **Verification Plan**:
  - Validate PowerShell AST parsing on all modified files.
  - Verify `Export-AntigravityExtractor.py` successfully extracts user prompts from the active SQLite database.
  - Run `Test-RepoReadiness.ps1` on `LCM_AI`.
  - Advance proposal state to `verified`.
