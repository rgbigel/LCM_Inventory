# Specification: CRP-357

Module: docs/Proposals/357_CRP-Single-Complete-Review-Tool-With-Review-Completion/Specification CRP-357.md  
Purpose: Single Complete-Review Tool With Review Completion Atoms  
Path: LCM_Inventory/docs/Proposals/357_CRP-Single-Complete-Review-Tool-With-Review-Completion/Specification CRP-357.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 23:22:39

```yaml
CRP-ID: CRP-357
Title: Single Complete-Review Tool With Review Completion Atoms
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 23:22:39
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic B): Submit-ReviewResult.ps1, Complete-ReviewCohort.ps1 and the complete/accept/proceed branches of Invoke-ProposalAction.ps1 overlap (staging, commit, receipts, lifecycle; auto-transition written four times). Target: one Complete-Review.ps1 (resolve target item or cohort, read-only plan over all changed governed repositories and open obligations, commit per repository, lifecycle once), pure parts in LcmReviewCompletionAtoms.psm1; old scripts become one-release forwarding shims, then retired with launchers and catalog rows; records aligned with RULE-REV-005/007 (receipt name, change_requests.json, version in log line).
- DOIT by operator instruction 2026-11-18 ("doit for all"); the Gate 0 contract below was set by Claude under that authorization.
- Review: this Specification and the Walkthrough. Plan: none beyond this Specification.

## 2. Gate 0 Contract
### Target State
- T1 One entry point `tools/Complete-Review.ps1` for one or more items or one cohort: members resolved first, refusal before any change when one is not ready, read-only `-Plan`, one commit per changed governed repository with a message naming all members, lifecycle once for all members; completed members only get their remaining repositories committed.
- T2 `Invoke-ProposalAction.ps1` (accept / complete / proceed) hands all Gate 2 targets of one call to it together; cohorts go through it; `Complete-ReviewCohort.ps1` is a forwarding shim; the changed-repository scan is `Get-LcmChangedGovernedRepositories` in `modules/LcmReviewCompletionAtoms.psm1`.
- T3 The review log line carries the workspace version (was a fixed 10.0.0).
- T4 (segment 2, open): the per-repository commit body of `Submit-ReviewResult.ps1` moves into the atoms module; `Submit-ReviewResult.ps1` and `Complete-ReviewCohort.ps1` with their launchers and catalog rows are retired one release later; receipt name and `change_requests.json` aligned with RULE-REV-005.

### Invariants and Exit Criteria
- ADMINMODE for rule paths, line-ending normalization and the BCR exclusion rule stay enforced (they live in the per-repository step); never pushes.
- Exit (segment 1): end-to-end tests with an isolated ledger and a stub commit step; existing lifecycle tests unchanged except the pre-existing transition-table case.

### Explicit Non-Goals
- Changing BCR or the review gate itself.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
