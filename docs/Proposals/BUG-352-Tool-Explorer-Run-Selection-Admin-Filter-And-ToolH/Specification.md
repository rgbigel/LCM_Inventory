# Specification: BUG-352

Module: docs/Proposals/BUG-352-Tool-Explorer-Run-Selection-Admin-Filter-And-ToolH/Specification.md  
Purpose: Tool Explorer Run Selection Admin Filter And ToolHelp Fail  
Path: LCM_Inventory/docs/Proposals/BUG-352-Tool-Explorer-Run-Selection-Admin-Filter-And-ToolH/Specification.md  
Authors: Rolf  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-18 12:20:01

```yaml
CRP-ID: BUG-352
Title: Tool Explorer Run Selection Admin Filter And ToolHelp Fail
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf
Date: 2026-11-18 12:20:01
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Tool Explorer defects found in the CRP-343 live tests 2026-11-17 (split from BUG-351 at its Gate 2, operator 2026-11-18).
(a) Run Selection posts {action:DO,target,parameters} to /api/action; the Go daemon needs a command string; no target resolution.
(b) Admin column filter options true/false vs filter code Admin/User.
(c) ToolHelp: no /tool_help route; fallback 2>&1 misses Write-Host (empty help file); Win11 Notepad opens a background tab in the existing non-elevated window.

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## Merged Findings

- [merged 2026-11-18 15:41:05] From analysis 2026-11-18 (topic B, operator option B): the BCR exclusion regex is copied in Submit-ReviewResult.ps1, Invoke-ProposalAction.ps1 and Complete-ReviewCohort.ps1 (the last copy is dead code) - keep one shared copy; the Control Hub calls Submit-ReviewResult.ps1 directly in two places (synthetic COH complete, "reviewed" action), bypassing the multi-repository completion of BUG-351 - route both through Invoke-ProposalAction.
