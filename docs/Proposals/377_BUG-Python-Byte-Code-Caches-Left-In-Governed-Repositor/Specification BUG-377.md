# Specification: BUG-377

Module: docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Specification BUG-377.md  
Purpose: Python Byte-Code Caches Left In Governed Repositories  
Path: LCM_Inventory/docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Specification BUG-377.md  
Authors: Claude  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 21:23:33

```yaml
CRP-ID: BUG-377
Title: Python Byte-Code Caches Left In Governed Repositories
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 21:23:33
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
The Claude line-ending hook (importing Repair-LcmLineEndings.py by file path) and the py_compile gate write __pycache__ folders into governed repositories (LCM_AI/.claude/hooks, LCM_Tools/tools), which are not git-ignored there. Fix: no byte-code writing by the hook and the gate (sys.dont_write_bytecode / python -B), and __pycache__/ ignored in every LCM repository.
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
