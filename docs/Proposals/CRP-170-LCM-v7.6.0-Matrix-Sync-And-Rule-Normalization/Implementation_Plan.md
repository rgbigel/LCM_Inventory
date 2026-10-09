# Implementation Plan: CRP-170

```yaml
CRP-ID: CRP-170
Title: Master Cross-Reference Matrix Synchronization, Rule Header Normalization, and Governance Fallback Codification
Scope: Multiple
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-24 18:21:00
Status: In_Progress
```

---

## 1. Planned Changes Breakdown

### Phase 1: Sanitize Rule Source Authority Headers
- Modify `LCM_Inventory\.agents\rules\PowerShellRules.md`:
  - Update `Path:` from `.agents/rules/PowerShellRules.md` to `.agents/rules/PowerShellRules.md`.
  - Remove `<!-- Source Authority: .agents/rules/PowerShellRules.md -->`.
- Modify `LCM_Inventory\.agents\rules\macro-definitions.md`:
  - Update `# location:` to `.agents/rules/macro-definitions.md`.
  - Remove `<!-- Source Authority: .agents/rules/macro-definitions.md -->`.

### Phase 2: Synchronize Master Cross-Reference Matrix & Root AGENTS.md
- Modify `LCM_AI\docs\LCM-Rules-Cross-Reference.md`:
  - Update header to `v7.6.0`.
  - Update discovery diagram to show Canonical Hub at `LCM_Inventory\.agents\rules\` linking to root `D:/Git_Repositories/.agents/rules/`.
  - Update table rows with all missing rules (`RULE-LCM-020`, `RULE-PS-015`, `RULE-REV-006..008`, `RULE-EFF-006..008`, `RULE-ENV-003`, `RULE-SUB-007`).
- Modify `D:\Git_Repositories\AGENTS.md`:
  - Update Quick-Reference table rows to accurately reflect `RULE-PS-001 - 015`, `RULE-EFF-001 - 008`, `RULE-SUB-001 - 007`.

### Phase 3: Normalize Rule Headers & Amend RULE-DOC-003
- Modify `LCM_Inventory\.agents\rules\DocumentationStandardsPolicy.md`:
  - Update `RULE-DOC-003` to codify the hybrid YAML frontmatter + DOX header format for `.agents/rules/*.md`.
- Modify `LCM_Inventory\.agents\rules\ElevationPolicy.md`:
  - Prepend standard YAML frontmatter and DOX header block.
- Modify `LCM_Inventory\.agents\rules\MethodEfficiencyPolicy.md`:
  - Prepend standard YAML frontmatter before the DOX header block.

### Phase 4: Codify Governance Tooling Fallback Clauses
- Modify `LCM_Inventory\.agents\rules\ReviewCommitGovernancePolicy.md`:
  - Add headless/non-interactive fallback to `RULE-REV-001`.
- Modify `LCM_Inventory\.agents\rules\MethodEfficiencyPolicy.md`:
  - Add search fallback to `RULE-EFF-007`.

### Phase 5: Mirror to `.agents/rules/` & Parity Verification
- Copy all 17 normalized rule files to `D:\Git_Repositories\.agents\rules\`.
- Compute SHA256 hashes to guarantee 100% cryptographic parity across all 17 rules.
- Populate `Walkthrough.md` with complete verification receipts.
