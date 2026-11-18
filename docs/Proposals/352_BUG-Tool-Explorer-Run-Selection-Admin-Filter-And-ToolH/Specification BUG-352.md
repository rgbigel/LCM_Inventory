# Specification: BUG-352

Module: docs/Proposals/352_BUG-Tool-Explorer-Run-Selection-Admin-Filter-And-ToolH/Specification BUG-352.md  
Purpose: Tool Explorer Run Selection Admin Filter And ToolHelp Fail  
Path: LCM_Inventory/docs/Proposals/352_BUG-Tool-Explorer-Run-Selection-Admin-Filter-And-ToolH/Specification BUG-352.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: In Progress (DOIT)  
Date: 2026-11-18 16:01:00

```yaml
CRP-ID: BUG-352
Title: Tool Explorer Run Selection Admin Filter And ToolHelp Fail
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf
Date: 2026-11-18 16:01:00
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Tool Explorer defects from the CRP-343 live tests (split from BUG-351) plus two review-completion items merged from the 2026-11-18 analysis (operator option B).
- Review: this Specification only; the Walkthrough holds the evidence and the browser tests still to be done by the operator.

## 2. Gate 0 Contract
### Target State
- T1 Run Selection / Run: the DO request carries the full command line (tool path plus parameters), so the Go daemon runs it.
- T2 Admin column filter: the dropdown values `true` / `false` select admin / non-admin tools.
- T3 ToolHelp: the tool's complete help text (including `Write-Host` output) is shown in a Notepad++ window in the foreground; no call to the missing `/tool_help` route.
- T4 One copy of the BCR exclusion rule (`modules/LcmReviewCompletionAtoms.psm1`), used by `Submit-ReviewResult.ps1` and `Invoke-ProposalAction.ps1`; the dead copy in `Complete-ReviewCohort.ps1` is removed.
- T5 The Control Hub "complete" (synthetic cohort) and "reviewed" actions use `Invoke-ProposalAction -Action complete` (multi-repository completion) instead of calling `Submit-ReviewResult.ps1` directly.

### Invariants and Exit Criteria
- Parse / `node --check` gates; completion tests pass; operator browser tests for T1-T3 and the two Control Hub actions.

### Explicit Non-Goals
- The single `Complete-Review.ps1` (CRP-357).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
## Merged Findings

- [merged 2026-11-18 15:41:05] From analysis 2026-11-18 (topic B, operator option B): the BCR exclusion regex is copied in Submit-ReviewResult.ps1, Invoke-ProposalAction.ps1 and Complete-ReviewCohort.ps1 (the last copy is dead code) - keep one shared copy; the Control Hub calls Submit-ReviewResult.ps1 directly in two places (synthetic COH complete, "reviewed" action), bypassing the multi-repository completion of BUG-351 - route both through Invoke-ProposalAction.
