# Change Request Proposal (CRP): Mandatory Review Stop & Turn Termination Invariant

Module: LCM_Inventory/docs/Proposals/CRP-022-Review-Stop-Turn-Termination-Invariant.md  
Purpose: Change Request Proposal for codifying RULE-REV-006 (Mandatory Review Stop & Turn Termination Invariant) in LCM governance policies.  
Path: LCM_Inventory/docs/Proposals/CRP-022-Review-Stop-Turn-Termination-Invariant.md  
Authors: Rolf, LCM_AI Engine  
Version: 1.0.0 (LCM Baseline: 7.0.0)  
Status: ACCEPTED / COMPLETED  
Date: 2026-08-30  

---

## 1. Executive Summary & Impact Classification

* **Proposal ID**: `CRP-022` (`CR-2026-033` / `Proposal #22`)
* **Target Domain**: `LCM Governance Rules (.agents/rules/)`
* **Impact Level**: `LOW` (Governance rule reinforcement).
* **Target Milestone**: `LCM v7.0.0`

---

## 2. Problem Statement & Motivation

Prior rule `RULE-REV-001` mandated that conversational chat directives do not waive visual review gating and that user review sign-off must be awaited. However, it lacked an explicit mechanical prohibition preventing the AI agent from launching Beyond Compare 5 and immediately executing `Submit-ReviewResult.ps1` in the very same turn based on ambiguous prior prompt phrases.

---

## 3. Specification of RULE-REV-006

Codify in [`ReviewCommitGovernancePolicy.md`](file:///.agents/rules/ReviewCommitGovernancePolicy.md):

```markdown
### RULE-REV-006: Mandatory Review Stop & Turn Termination Invariant
1. **Mandatory Turn Termination**: Whenever an agent carries out a CRP or code modification reaching the visual review stage, the agent `MUST` launch `Invoke-BeyondCompareReview.ps1` and **immediately terminate the current response turn without making additional tool calls**.
2. **Prohibition of Same-Turn Submissions**: The agent `MUST NOT` invoke `Submit-ReviewResult.ps1`, stage files, or execute `git commit` within the same execution turn cycle as the review launcher.
3. **Discrete Operator Disposition Requirement**: Review dispositions (`ACCEPTED`, `ACCEPTED_WITH_EDITS`, `REJECTED`, `DEFERRED`) `SHALL ONLY` be consumed and processed when received as a discrete, independent message submitted by the operator in a subsequent turn.
```

---

## 4. Verification & Quality Gates

* **Rule Health Audit**: Validated via `ValidateRules.ps1` and `Test-WorkspaceReadiness.ps1`.
* **Export Mirroring**: Exported to consolidated master artifacts (`LCM_Rules_Gemini_Export.md`, `LCM_Rules.txt`) and mirrored to Google Drive.

