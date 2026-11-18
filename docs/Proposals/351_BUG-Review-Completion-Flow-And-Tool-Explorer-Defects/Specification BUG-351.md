# Specification: BUG-351

Module: docs/Proposals/351_BUG-Review-Completion-Flow-And-Tool-Explorer-Defects/Specification BUG-351.md  
Purpose: Review Completion Flow And Proposal Registration Defects  
Path: LCM_Inventory/docs/Proposals/351_BUG-Review-Completion-Flow-And-Tool-Explorer-Defects/Specification BUG-351.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: In Review  
Date: 2026-11-18 12:20:46

```yaml
CRP-ID: BUG-351
Title: Review Completion Flow And Proposal Registration Defects
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-18 12:20:46
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
Completing an item that changed several repositories committed only one of them and then closed the item (CRP-350, 2026-11-17); a new BUG could not be registered through the governed action. This BUG fixes both.
- Review: this Specification is sufficient. Read the Walkthrough only for the one design choice made without the operator (obligations are registered at completion, not at BCR launch) and for 3 pre-existing test failures.
- Scope change at Gate 2 (operator 2026-11-18): the Tool Explorer items (Run Selection, Admin filter, ToolHelp) moved to BUG-352; the bundle name keeps the original title.

## 2. Gate 0 Contract
### Target State
- T1: `COMPLETE <ID>` (also `proceed` to completed and Gate 2 `accept`) commits every governed repository (root, `LCM_AI`, `LCM_Inventory`, `LCM_Shared`, `LCM_Supervision`, `LCM_Tools`) that has committable changes, because one BCR review covers the whole workspace. The item becomes `completed` only with the last repository.
- T2: the per-repository commit tool no longer falls back to the workspace root when no repository is given; it stops and names `COMPLETE`.
- T3: `bug` / `suggest` without a target create a new BUG / CRP; `bug <BUG-ID> -Details` merges a finding into that BUG.

### Invariants and Exit Criteria
- Repositories outside the governed list are never committed by a completion.
- Parse gate zero errors; tests for T1-T3 pass; no new failures in the existing lifecycle tests.

### Explicit Non-Goals
- Tool Explorer defects (BUG-352).
- Rule clarifications for completion precondition, implied cohorts, DOIT and bare `bcr` (CRP-346 section 4).
- Declared-cohort completion (`COH-<n>`), ledger store consolidation (decision B).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
