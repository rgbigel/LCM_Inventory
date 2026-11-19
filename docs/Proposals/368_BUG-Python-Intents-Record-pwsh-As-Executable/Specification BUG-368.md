# Specification: BUG-368

Module: docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Specification BUG-368.md  
Purpose: Python Intents Record pwsh As Executable  
Path: LCM_Inventory/docs/Proposals/368_BUG-Python-Intents-Record-pwsh-As-Executable/Specification BUG-368.md  
Authors: Claude  
Version: 10.7.4  
Status: Completed  
Date: 2026-11-19 15:59:34

```yaml
CRP-ID: BUG-368
Title: Python Intents Record pwsh As Executable
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 15:59:34
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Update-ToolCatalog.ps1 writes executable = pwsh.exe for 60 Python intents (tool_intents); RULE-PY-010 requires the registered interpreter. Found during CRP-361 T6 registration. Also observed (not changed): .reg (12), .lnk (10), .txt (4) intents carry pwsh.exe.
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

## Target State

Python intents name the registered interpreter (RULE-PY-010); the documentation check keeps working with full paths.
