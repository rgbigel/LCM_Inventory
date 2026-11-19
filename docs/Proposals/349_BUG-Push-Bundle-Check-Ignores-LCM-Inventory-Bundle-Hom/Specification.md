# Specification: BUG-349

Module: docs/Proposals/349_BUG-Push-Bundle-Check-Ignores-LCM-Inventory-Bundle-Hom/Specification.md  
Purpose: Push Bundle Check Ignores LCM Inventory Bundle Home  
Path: LCM_Inventory/docs/Proposals/349_BUG-Push-Bundle-Check-Ignores-LCM-Inventory-Bundle-Hom/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4  
Status: Pushed  
Date: 2026-11-17 14:53:49

```yaml
CRP-ID: BUG-349
Title: Push Bundle Check Ignores LCM Inventory Bundle Home
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 14:53:49
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 9
App-ID: None
```

---

## 1. Executive Summary & Intent
Blocks PUSH 2026-11-17: Test-LCM_ProposalBundlesInHead (modules/LCM_PushEligibility.psm1) looks for a proposal bundle in the HEAD of the proposal origin_repo; per RULE-LCM-034 / RULE-SUB-008 bundles of governed LCM_* repos (LCM_AI, LCM_Inventory, LCM_Shared, LCM_Supervision, LCM_Tools) live only in LCM_Inventory. CRP-331 and BUG-342 (origin LCM_AI) are refused although their bundles are committed in LCM_Inventory.

## 2. Gate 0 Contract
BUG: target inherent in the defect (RULE-GOAL-002). Operator 2026-11-17: bookkeeping is not reviewable and never a cause to abort anything ("you can't change the bible using the bible"); SQL projections are pushed in the final state of the tables.

### Target State
- The push bundle check looks in LCM_Inventory for bundles of governed LCM_* proposals (RULE-LCM-034) and only warns when a bundle is missing; it never aborts a push.
- `Invoke-LCM_Push.ps1` exports the SQL ledger projections and commits them (`chore(ledger)`, path-limited, no hooks) before pushing, so the pre-push projection check never refuses.
- RULE-EFF-001 lists the SQL projections as mechanical artifacts; RULE-EFF-002 states that bookkeeping never aborts a commit, push or lifecycle step.

### Invariants and Exit Criteria
- Non-bookkeeping push preconditions (completed proposals, lockstep, ahead state) unchanged.
- Exit: parse gate; `LCM_PushEligibility.Tests.ps1` 7/7; dry run lists the 9 completed proposals; real push publishes LCM_Inventory and moves the 9 proposals to `pushed`.

### Explicit Non-Goals
- Changing the pre-push hook itself (`.githooks/pre-push`); the push tool commits the projection first, so the hook passes.
- Dry-run side effects of `Invoke-LCM_Maintenance.ps1` (BUG-348).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## Absorbed Operator Remarks

> "data/proposals/proposals.sql changed during the push run ", well it must, but this is clearly and case of an artifact (used only in the case of a Pull to get back at an older version). Since we will not ever use this, force .sql files to be pushed in the final state corresponding to the tables.
> I do not understand the bug blocker 349 reasoning. you did find what the wrong location is at fault, which is bookkeeping. bookkeeping changes are not reviewable, not usable as a cause to abort anything: you can't change the bible using the bible.

(Operator, 2026-11-17.)