# Specification: BUG-383

Module: docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Specification BUG-383.md  
Purpose: Learned Advice Review Blocks Push Although Never Reviewed  
Path: LCM_Inventory/docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Specification BUG-383.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 00:40:14

```yaml
CRP-ID: BUG-383
Title: Learned Advice Review Blocks Push Although Never Reviewed
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 00:40:14
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-20: learned advice is administrative data / an artifact and is never reviewed; the push gate in Invoke-LCM_Push.ps1 (RULE-CTX-005 "review candidates before publish") refused the GoodNight push because one candidate was pending. Target: candidates no longer block a push and need no operator review (accepted by the contributing host); RULE-CTX-005 and the gate changed accordingly (rule change: ADMINMODE, RULE-AUTH-002 sync).
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
