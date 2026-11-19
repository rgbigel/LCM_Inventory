# Specification: CRP-381

Module: docs/Proposals/381_CRP-Standard-Navigation-Hierarchy-Of-Fundamental-LCM-D/Specification CRP-381.md  
Purpose: Standard Navigation Hierarchy Of Fundamental LCM Displays  
Path: LCM_Inventory/docs/Proposals/381_CRP-Standard-Navigation-Hierarchy-Of-Fundamental-LCM-D/Specification CRP-381.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 00:23:46

```yaml
CRP-ID: CRP-381
Title: Standard Navigation Hierarchy Of Fundamental LCM Displays
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 00:23:46
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator (live test 2026-11-20): "we must define a standard hierarchy of the fundamental tools of LCM (not the other
tools)." Found because the Inventory Explorer offers no way back to the Tools Explorer, unlike other displays, which
show "Back" or sometimes "Close" (BUG-380 B10).

## 2. Gate 0 Contract (draft, for operator acceptance)

### Target State

T1 A documented hierarchy of the fundamental LCM displays (e.g. Tools Explorer as entry point; Control Hub, Inventory
Explorer, Rules, Tool Intents and the other standard displays below it), defined by the operator.

T2 Uniform navigation in every fundamental display: one control back to its parent in the hierarchy, with one name
and one place (Back vs. Close decided once).

### Invariants and Exit Criteria

- Only the fundamental LCM displays; other tools are out of scope.
- Exit: operator live test walks the hierarchy up and down from every fundamental display.

### Explicit Non-Goals

- Restyling the displays (BUG-380 covers the visual defects).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Open Operator Questions

- Which displays count as fundamental, and which one is the root?
- One control name: "Back" or "Close"?
