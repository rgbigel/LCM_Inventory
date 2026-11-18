# Specification: BUG-356

Module: docs/Proposals/BUG-356-Rules-Explorer-Has-No-Refresh-Button/Specification BUG-356.md  
Purpose: Rules Explorer Has No Refresh Button  
Path: LCM_Inventory/docs/Proposals/BUG-356-Rules-Explorer-Has-No-Refresh-Button/Specification BUG-356.md  
Authors: Rolf  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 15:40:57

```yaml
CRP-ID: BUG-356
Title: Rules Explorer Has No Refresh Button
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:40:57
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Analysis 2026-11-18 (topic A): Show-Rules.ps1 re-reads the rule files on every render, but only F5 triggers a re-render (POST /displays/refresh/rules); the page function refreshRules() has no button, RULE-DSP-003 requires a topbar refresh control. Fix: topbar refresh button calling the refresh, following the Control Hub btnRefresh pattern. Automatic re-render on rule-file changes is a separate CRP (after the JSON retirement).
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
