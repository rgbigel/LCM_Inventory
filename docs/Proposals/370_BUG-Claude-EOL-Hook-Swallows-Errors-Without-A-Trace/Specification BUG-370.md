# Specification: BUG-370

Module: docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Specification BUG-370.md  
Purpose: Claude EOL Hook Swallows Errors Without A Trace  
Path: LCM_Inventory/docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Specification BUG-370.md  
Authors: Claude  
Version: 10.7.4  
Status: In Review  
Date: 2026-11-19 16:24:42

```yaml
CRP-ID: BUG-370
Title: Claude EOL Hook Swallows Errors Without A Trace
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 16:24:42
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
invoke_claude_eol_hook.py swallows every error (except: pass) and ignores status failed from repair_file; errors stay invisible. Fix: log every error and failed result to LCM_Inventory/logs/claude-eol-hook.log, still exit 0. Operator 2026-11-19: required for Gate 2 acceptance.
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

The hook never blocks a tool call (exit 0) and never loses an error: every error and every failed conversion is logged (operator 2026-11-19: required for Gate 2 acceptance).
