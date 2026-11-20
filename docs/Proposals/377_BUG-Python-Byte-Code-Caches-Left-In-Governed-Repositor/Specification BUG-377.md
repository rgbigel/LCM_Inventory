# Specification: BUG-377

Module: docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Specification BUG-377.md  
Purpose: Python Byte-Code Caches Left In Governed Repositories  
Path: LCM_Inventory/docs/Proposals/377_BUG-Python-Byte-Code-Caches-Left-In-Governed-Repositor/Specification BUG-377.md  
Authors: Claude  
Version: 10.7.4  
Status: Pushed  
Date: 2026-11-20 16:51:15

```yaml
CRP-ID: BUG-377
Title: Python Byte-Code Caches Left In Governed Repositories
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-20 16:51:15
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
The Claude line-ending hook (importing Repair-LcmLineEndings.py by file path) and the py_compile gate write __pycache__ folders into governed repositories (LCM_AI/.claude/hooks, LCM_Tools/tools), which are not git-ignored there. Fix: no byte-code writing by the hook and the gate (sys.dont_write_bytecode / python -B), and __pycache__/ ignored in every LCM repository.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
No Python byte-code cache shows up as untracked content in an LCM repository: the Claude hooks run without writing byte-code, and `__pycache__/` is ignored in every LCM repository.

### Invariants and Exit Criteria
- No other change; hooks behave as before.

### Explicit Non-Goals
- The py_compile syntax gate keeps writing caches (by design of py_compile); they are ignored now.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
