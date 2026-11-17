# Specification: BUG-342

Module: docs/Proposals/BUG-342-LCM-AI-Package-Docs-Version-Not-Aligned-To-10-7-4/Specification.md  
Purpose: LCM_AI Package Docs Version Not Aligned To 10.7.4  
Path: LCM_Inventory/docs/Proposals/BUG-342-LCM-AI-Package-Docs-Version-Not-Aligned-To-10-7-4/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: In Progress  
Date: 2026-11-17 12:15:57

```yaml
CRP-ID: BUG-342
Title: LCM_AI Package Docs Version Not Aligned To 10.7.4
Scope: LCM_AI
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 12:15:57
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
COMPLETE COH-331 blocked 2026-11-17 by LcmPackageVersion gate: LCM_AI docs/Architecture.md, docs/Requirements.md, docs/Implementation.md (Version:) and README.md (LCM Governance Baseline) declare 10.6.4; maximum owned component version is 10.7.4 since the WIP publish of 2026-11-15. Fix: align the four declarations to 10.7.4.

## 2. Gate 0 Contract
### Target State
BUG: target inherent in the defect (RULE-GOAL-002). The four LCM_AI package declarations equal the maximum owned component version (10.7.4), so `Assert-LcmPackageVersion` passes and COMPLETE COH-331 can proceed.

### Invariants and Exit Criteria
Only the `Version:` / `Date:` header lines and the README baseline line change; exit: `Assert-LcmPackageVersion -RepositoryPath LCM_AI -WorkingTree` passes.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## 4. Operator Correction and Rule Codification (2026-11-17)
> correction for bug-342: corrections for version alignments NEVER need CRP or BUG generation. Reason: the consistency mechanism of CM mandate these changes automatically. So while BUG 342 is superfluous, it does no harm, so I ask you to codify this rule limitation IMMEDIATELY under BUG 342, then DOIT 342 = Complete 342

- Codified as `RULE-REV-007` item 4 (Version Alignment Exemption, `ReviewCommitGovernancePolicy.md` 10.3.1) and `RULE-LCM-010` item 4 (exception pointer, `ProposalReviewFlowPolicy.md` 10.3.1); synced per `RULE-AUTH-002`: root `AGENTS.md`, `LCM_AI/docs/LCM-Rules-Cross-Reference.md`, Claude adapter `.claude/rules/process/` (2 files), `.claude/translation/CANONICAL_HASHES.md`. `GEMINI.md` carries no REV-007/LCM-010 text (export refreshed at push, `RULE-LCM-013`).
- BUG-342 itself is superfluous under the new rule; kept as the record of the codification (operator).
