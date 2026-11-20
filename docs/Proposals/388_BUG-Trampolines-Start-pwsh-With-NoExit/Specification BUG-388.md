# Specification: BUG-388

Module: docs/Proposals/388_BUG-Trampolines-Start-pwsh-With-NoExit/Specification BUG-388.md  
Purpose: Trampolines Start pwsh With NoExit  
Path: LCM_Inventory/docs/Proposals/388_BUG-Trampolines-Start-pwsh-With-NoExit/Specification BUG-388.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: In Review  
Date: 2026-11-20 15:39:37

```yaml
CRP-ID: BUG-388
Title: Trampolines Start pwsh With NoExit
Scope: LCM_Inventory
Baseline-Version: 10.8.4
Author: Rolf, Claude
Date: 2026-11-20 15:39:37
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-20 (live test): generated trampolines (Update-ToolCatalog, e.g. DoT/LCMPush.cmd, DoT/ProposalAction.cmd) start pwsh -NoExit, leaving a nested shell; trampolines hold no logic that needs debugging, so no -NoExit. Minor; fixed after the 10.8.4 push.
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
