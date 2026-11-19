# Specification: BUG-360

Module: docs/Proposals/360_BUG-Completion-Aborts-On-Tracked-File-Under-Ignored-Di/Specification BUG-360.md  
Purpose: Completion Aborts On Tracked File Under Ignored Directory  
Path: LCM_Inventory/docs/Proposals/360_BUG-Completion-Aborts-On-Tracked-File-Under-Ignored-Di/Specification BUG-360.md  
Authors: Rolf  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 18:35:11

```yaml
CRP-ID: BUG-360
Title: Completion Aborts On Tracked File Under Ignored Directory
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 18:35:11
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Found 2026-11-18 while completing CRP-346: Submit-ReviewResult.ps1 (line ~276) stages each reviewed path with "git add -A -- <path>" and throws when git exits non-zero. In LCM_AI, .gitignore line 9 "logs/" matches docs/Logs case-insensitively (core.ignorecase); the tracked file docs/Logs/03_Propagation-and-Continuous-History/Major_Version_Milestone_Rollup.md is staged but git exits 1 with the "paths are ignored" advice, so completion aborts after the root repository was committed. Fix: treat the add as successful when the path has no unstaged change left; untracked ignored paths still fail.
- Review: this Specification only (Plan and Walkthrough not written yet).
- Review: the Walkthrough (Gate 2 exception recorded there). Plan: none beyond this Specification.

## 2. Gate 0 Contract
### Target State
- `Submit-ReviewResult.ps1` stages a tracked reviewed path under a directory matched by `.gitignore` (git exits 1 but stages it) and continues; an untracked ignored path still fails.

### Invariants and Exit Criteria
- No ignored untracked file is committed; the BCR exclusion rule is unchanged.
- Exit: the CRP-346 completion passes LCM_AI with `docs/Logs/.../Major_Version_Milestone_Rollup.md`; Pester test green.

### Explicit Non-Goals
- Changing `.gitignore` of LCM_AI (`logs/` stays; it matches `docs/Logs` only case-insensitively).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
