# Specification: CRP-373

Module: docs/Proposals/373_CRP-Readiness-Gate-Completeness-Against-The-Rules/Specification CRP-373.md  
Purpose: Readiness Gate Completeness Against The Rules  
Path: LCM_Inventory/docs/Proposals/373_CRP-Readiness-Gate-Completeness-Against-The-Rules/Specification CRP-373.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 17:18:18

```yaml
CRP-ID: CRP-373
Title: Readiness Gate Completeness Against The Rules
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 17:18:14
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator 2026-11-19: the LCM_Inventory readiness gate (Test-RepoReadiness.ps1, built 2026-11-19) stays; it is checked
directly against the rules for completeness only (not against the old gates); test code is aligned to the rules without
operator questions.

## 2. Gate 0 Contract

### Target State

T1 A rule-to-check table: every canonical rule ID with its mechanical check in the gate, or "not mechanizable".

T2 Missing mechanical checks are added; the Python unit tests (tests/test_*.py, unittest) run in gate 4 next to Pester.

### Invariants and Exit Criteria

- The gate keeps running the unit tests in a clean child process (BUG-364 T4).
- Exit: the table covers every rule ID; the gate runs Pester and the Python tests and passes.

### Explicit Non-Goals

- Re-implementing the old per-repository gates of other repositories.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## Operator Decisions (2026-11-19 17:32:57)

- Test isolation (tests writing into live stores) belongs to BUG-375; CRP-373 only references it and stays the rule-to-check completeness work.
