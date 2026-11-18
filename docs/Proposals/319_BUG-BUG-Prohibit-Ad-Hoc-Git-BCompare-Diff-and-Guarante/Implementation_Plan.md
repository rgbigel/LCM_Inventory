# Implementation Plan: BUG-319 - [BUG] Prohibit Ad-Hoc Git BCompare Diff and Guarantee BCR Exclusivity

## 1. Executive Summary & Problem Context
An agent previously fell back to an ad-hoc Beyond Compare command targeting only `LCM_AI` against a GitHub commit when today's Macrium Reflect backup had not yet been mounted. This bypassed the mandatory `BCR` review architecture, failed to mount the daily backup, and excluded changes in all sibling repositories (including `LCM_Inventory/tools`).

## 2. Gate 0 Traceability
- **Clause 1**: Add `RULE-REV-014` to `ReviewCommitGovernancePolicy.md` explicitly banning ad-hoc BCompare executions.
- **Clause 2**: Mandate `BCR` exclusivity and workspace-wide root scope (`_LCM` profile).
- **Clause 3**: Synchronize `AGENTS.md` and `LCM-Rules-Cross-Reference.md`.
- **Clause 4**: Validate readiness gates and launch `BCR` for operator review.

## 3. Proposed Changes
### Component 1: ReviewCommitGovernancePolicy.md
- Add `RULE-REV-014: Prohibition of Ad-Hoc / Git-Based BCompare Invocations & Exclusivity of BCR Invariant`.
- Update version header to 10.2.4 and date to 2026-11-11.

### Component 2: Discovery Synchronizations
- Update `AGENTS.md` Quick-Reference table (`RULE-REV-001` - `014`).
- Update `LCM_AI/docs/LCM-Rules-Cross-Reference.md` row 4.

## 4. Verification Plan
- Syntax validation via AST parser.
- Repository quality gates (`Test-RepoReadiness.ps1`).
- Gate 2 visual diff review dispatch via `BCR`.
