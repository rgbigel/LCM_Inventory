# Walkthrough: BUG-319 - [BUG] Prohibit Ad-Hoc Git BCompare Diff and Guarantee BCR Exclusivity

## 1. Executive Summary
- **Proposal ID**: `BUG-319`
- **Scope**: `LCM_AI`, `LCM_Inventory`
- **Problem**: An agent attempted an ad-hoc Beyond Compare comparison against a GitHub/Git revision baseline when today's Macrium Reflect backup had not yet been mounted. This bypassed the mandatory `BCR` review architecture, failed to mount the daily backup, and excluded changes in all sibling repositories (including `LCM_Inventory/tools`).
- **Resolution**: Added `RULE-REV-014: Prohibition of Ad-Hoc / Git-Based BCompare Invocations & Exclusivity of BCR Invariant` to `ReviewCommitGovernancePolicy.md`, bumped version to `10.2.4`, updated `AGENTS.md` and `LCM-Rules-Cross-Reference.md`, and prepared `BUG-319` for Gate 2 visual review via `BCR`.

## 2. Changes Made
1. **`ReviewCommitGovernancePolicy.md`**:
   - Added `RULE-REV-014: Prohibition of Ad-Hoc / Git-Based BCompare Invocations & Exclusivity of BCR Invariant`.
   - Bumped version to `10.2.4` and updated timestamp to `2026-11-11 15:30:00`.
2. **`AGENTS.md`**:
   - Updated Rule Index table row for `ReviewCommitGovernancePolicy.md` to `RULE-REV-001` - `014` with summary of `RULE-REV-014`.
3. **`LCM_AI/docs/LCM-Rules-Cross-Reference.md`**:
   - Updated cross-reference table row 4 to include `RULE-REV-014`.
4. **`BUG-319` Proposal Bundle**:
   - Authored `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.

## 3. Verification Evidence
- Governance static analysis and AST checks passed.
- Unit tests (`LcmDisplayVersion.Tests.ps1`, `ToolValidation.Tests.ps1`) passing 100%.
- Ready for Gate 2 visual review via `BCR`.
