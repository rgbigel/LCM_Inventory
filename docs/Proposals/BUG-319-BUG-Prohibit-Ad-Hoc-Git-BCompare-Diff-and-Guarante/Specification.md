# Change Request Proposal: BUG-319

```yaml
CRP-ID: BUG-319
Title: [BUG] Prohibit Ad-Hoc Git BCompare Diff and Guarantee BCR Exclusivity
Scope: LCM_AI, LCM_Inventory
Baseline-Version: 10.2.4
Author: Rolf, LCM_AI Engine
Date: 2026-11-11 15:30:00
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Remediates a governance bypass where an agent erroneously launched an ad-hoc Beyond Compare command comparing an isolated repository (`LCM_AI`) against a GitHub/Git revision baseline when today's Macrium Reflect backup was not yet mounted.

This proposal:
1. Codifies `RULE-REV-014` in `ReviewCommitGovernancePolicy.md`, strictly prohibiting ad-hoc BCompare execution against Git refs or single-repo subtrees.
2. Formally mandates that `BCR` is the exclusive method for baseline comparison workspace-wide.
3. Requires all baseline comparisons to execute against the workspace root (`<MountedDrive>:\Git_Repositories` vs `D:\Git_Repositories`) using the operator-owned `_LCM` Beyond Compare profile.
4. Synchronizes the root `AGENTS.md` index and `LCM-Rules-Cross-Reference.md` per `RULE-REV-009`.

## 2. Gate 0 Contract
### Target State
- `ReviewCommitGovernancePolicy.md` contains authoritative rule `RULE-REV-014: Prohibition of Ad-Hoc / Git-Based BCompare Invocations & Exclusivity of BCR Invariant`.
- Ad-hoc BCompare command lines and Git-based baseline comparisons are formally declared invalid and forbidden.
- Root `AGENTS.md` and `LCM_AI/docs/LCM-Rules-Cross-Reference.md` are synchronized with the new rule range (`RULE-REV-001` - `014`).
- All repository readiness gates pass with zero errors.

### Invariants and Exit Criteria
- `RULE-REV-014`: Prohibition of Ad-Hoc / Git-Based BCompare Invocations & Exclusivity of BCR Invariant.
- `RULE-REV-009`: Review Discovery Disclosure and Durable Governance Closure.
- `RULE-REV-011`: ADMINMODE Rule-Change Authorization Invariant satisfied.
- 100% pass on general readiness gates across `LCM_AI` and `LCM_Inventory`.

### Explicit Non-Goals
- Cause no havoc. Does not alter the underlying `Invoke-MacriumDailyBcrBaseline.ps1` implementation or modify other governance policies outside the review scope.

## 3. Technical Requirements & Invariants
- Invariant 1: `ReviewCommitGovernancePolicy.md` version bumped to 10.2.4 with updated modification timestamp.
- Invariant 2: Discovery cross-references in `AGENTS.md` and `LCM-Rules-Cross-Reference.md` updated in the same change set.
- Invariant 3: Gate 2 visual diff review launched exclusively via `BCR`.
