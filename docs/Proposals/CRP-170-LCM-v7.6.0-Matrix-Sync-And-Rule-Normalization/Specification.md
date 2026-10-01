# Change Request Proposal: CRP-170

```yaml
CRP-ID: CRP-170
Title: Master Cross-Reference Matrix Synchronization, Rule Header Normalization, and Governance Fallback Codification
Scope: Multiple
Affected-Scopes:
  - LCM_AI
  - LCM_Inventory
  - D:\Git_Repositories
  - D:\Git_Repositories\.copilot
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-24 18:21:00
Status: In_Progress
Plan-State: approved
Progress-State: in_progress
Priority: High
App-ID: Architecture
```

---

## 1. Executive Summary & Intent

Following the deployment of the root `.agents` directory junction, command taxonomy reconciliation, and `.copilot` cleanup in `CRP-169`, this proposal resolves all remaining governance desynchronization and formatting discrepancies identified in `DivergenceCorrection.md`:
1. **Sanitize Legacy `.copilot` Source Authority Headers**: `PowerShellRules.md` and `macro-definitions.md` still contain legacy `.copilot/Rules/` source authority comments and paths, violating `RULE-AUTH-001`.
2. **Master Cross-Reference Matrix & AGENTS.md Synchronization**: `LCM_AI/docs/LCM-Rules-Cross-Reference.md` is on stale baseline `v6.1.1` and omits multiple active rules (`RULE-LCM-020`, `RULE-PS-015`, `RULE-REV-006..008`, `RULE-EFF-006..008`, `RULE-ENV-003`, `RULE-SUB-007`). Root `AGENTS.md` is also desynchronized. Both must be updated to LCM baseline `v7.6.0` per `RULE-AUTH-002`.
3. **DOX Header Invariant & Rule Header Normalization**: Amend `RULE-DOC-003` to formally recognize the hybrid YAML frontmatter + DOX header format for rule files. Normalize `ElevationPolicy.md` and `MethodEfficiencyPolicy.md` to conform.
4. **Governance Tooling Fallback Codification**: Codify headless and non-interactive fallbacks for Beyond Compare 5 and Everything HTTP REST search across governance policies.
5. **Full Parity Synchronization to `.copilot/Rules/`**: Ensure all updated rules are mirrored to `.copilot/Rules/` with 100% cryptographic SHA256 parity.

---

## 2. Requirements & Invariants

### Requirement 1: Sanitize Authority Headers in Canonical Rules
- In `LCM_Inventory\.agents\rules\PowerShellRules.md`:
  - Update `Path:` to `.agents/rules/PowerShellRules.md`.
  - Remove obsolete `<!-- Source Authority: .copilot/Rules/... -->`.
- In `LCM_Inventory\.agents\rules\macro-definitions.md`:
  - Update `# location:` to `.agents/rules/macro-definitions.md`.
  - Remove obsolete `<!-- Source Authority: .copilot/Rules/... -->`.

### Requirement 2: Synchronize LCM Cross-Reference Matrix & Root AGENTS.md
- In `LCM_AI/docs/LCM-Rules-Cross-Reference.md`:
  - Update baseline header to `v7.6.0`.
  - Update Section 1 diagram to reflect canonical hub at `LCM_Inventory\.agents\rules\` and root junction at `D:/Git_Repositories/.agents/rules/`.
  - Update Master Table with all omitted rules:
    - Table Row 1: `RULE-LCM-001` through `RULE-LCM-020`
    - Table Row 2: `RULE-PS-001` through `RULE-PS-015`
    - Table Row 4: `RULE-REV-001` through `RULE-REV-008`
    - Table Row 5: `RULE-EFF-001` through `RULE-EFF-008` & `RULE-ENV-003`
    - Table Row 16: `RULE-SUB-001` through `RULE-SUB-007`
- In root `AGENTS.md`:
  - Synchronize the Quick-Reference table rows to include all missing rule ranges.

### Requirement 3: Amend RULE-DOC-003 and Normalize Rule Headers
- In `LCM_Inventory\.agents\rules\DocumentationStandardsPolicy.md` (`RULE-DOC-003`):
  - Codify that `.agents/rules/*.md` files begin with YAML frontmatter (Lines 1–5 for IDE rule indexing), followed immediately by the standard DOX metadata header.
- Normalize `ElevationPolicy.md`:
  - Add YAML frontmatter (`--- name: ElevationPolicy ... ---`) and standard DOX header (`# File: ElevationPolicy.md ... Module: ElevationPolicy ...`).
- Normalize `MethodEfficiencyPolicy.md`:
  - Add YAML frontmatter (`--- name: MethodEfficiencyPolicy ... ---`) preceding the DOX header.

### Requirement 4: Codify Governance Tooling Fallback Clauses
- In `ReviewCommitGovernancePolicy.md` (`RULE-REV-001` / `RULE-REV-008`):
  - Codify headless/non-interactive fallback: If Beyond Compare 5 GUI is unavailable, fall back to unified console diffs and `Walkthrough.md` evidence review.
- In `MethodEfficiencyPolicy.md` (`RULE-EFF-007`):
  - Codify search fallback: If Everything 1.5a HTTP REST daemon (port 8080) is unreachable, fall back to `rg.exe` or `Get-ChildItem`.

### Requirement 5: Cryptographic Parity Mirroring
- Mirror all normalized and updated rules from `LCM_Inventory\.agents\rules\` into `D:\Git_Repositories\.copilot\Rules\`.
- Assert 100% SHA256 cryptographic parity across all 17 rules.
