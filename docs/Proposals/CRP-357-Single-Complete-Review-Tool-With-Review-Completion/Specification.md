# Specification: CRP-357

Module: docs/Proposals/CRP-357-Single-Complete-Review-Tool-With-Review-Completion/Specification.md  
Purpose: Single Complete-Review Tool With Review Completion Atoms  
Path: LCM_Inventory/docs/Proposals/CRP-357-Single-Complete-Review-Tool-With-Review-Completion/Specification.md  
Authors: Rolf  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 15:41:00

```yaml
CRP-ID: CRP-357
Title: Single Complete-Review Tool With Review Completion Atoms
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:41:00
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic B): Submit-ReviewResult.ps1, Complete-ReviewCohort.ps1 and the complete/accept/proceed branches of Invoke-ProposalAction.ps1 overlap (staging, commit, receipts, lifecycle; auto-transition written four times). Target: one Complete-Review.ps1 (resolve target item or cohort, read-only plan over all changed governed repositories and open obligations, commit per repository, lifecycle once), pure parts in LcmReviewCompletionAtoms.psm1; old scripts become one-release forwarding shims, then retired with launchers and catalog rows; records aligned with RULE-REV-005/007 (receipt name, change_requests.json, version in log line).
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.
