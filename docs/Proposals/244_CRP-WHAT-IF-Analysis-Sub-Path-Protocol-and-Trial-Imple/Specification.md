# Change Request Proposal: CRP-244

```yaml
CRP-ID: CRP-244
Title: WHAT-IF Analysis Sub-Path Protocol and Trial Implementation Branching
Scope: LCM_AI, LCM_Inventory, Workspace Governance
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
When a Change Request Proposal (CRP) is unfinalized, encounters unforeseen architectural blockers, or generates conflicting requirements during implementation/review, operators require a mechanism to explore alternative hypotheses without corrupting the existing working tree or prematurely committing experimental code.

This proposal establishes the **`WHAT-IF` Analysis Sub-Path Protocol**: an exploratory workflow initiated inside `READ_ONLY_ANALYSIS` mode that captures a pre-trial baseline snapshot, enables a bounded **Trial Implementation**, and presents it at a dedicated visual review gate. If accepted, the trial is promoted; if rejected, the pre-trial baseline is restored with 100% fidelity, and the session returns to `READ_ONLY_ANALYSIS` to evaluate alternative paths.

---

## 2. Operational Rules & State Machine

### 2.1 Trigger & Snapshot Invariant
- **`ANALYZE WHAT-IF: <Hypothesis>`**: Initiates an exploratory sub-path linked to the active CRP.
- **Pre-Trial Checkpoint**: Before modifying any files for the trial, the engine automatically creates a lightweight working copy snapshot in `LCM_Inventory/scratch/what_if/<CRP_ID>/checkpoint/` or via a dedicated Git stash reference (`refs/stash/what_if_<CRP_ID>`).
- **Telemetry Register**: `LCM_WhatIfActive = true`, `LCM_WhatIfParentCRP = <ID>`, `LCM_WhatIfHypothesis = <Text>`.

### 2.2 Trial Implementation Mode
- The session transitions to `TRIAL_IMPLEMENTATION` (a specialized sub-state of `GOVERNED_IMPLEMENTATION`).
- Code edits, configuration updates, and unit tests are executed strictly within the scope of the stated `WHAT-IF` hypothesis.
- Git commits to the main branch are prohibited during this phase.

### 2.3 Review Gate & Dual-Disposition Resolution
At the conclusion of the trial, a standard Beyond Compare 5 review session is launched:
- **Left Pane**: Pre-trial baseline snapshot.
- **Right Pane**: Trial implementation working tree.

**Operator Disposition Options:**
1. **`ACCEPT (Promote)`**:
   - The trial changes are confirmed.
   - The parent CRP's `Specification.md` and `Implementation_Plan.md` are amended with an addendum documenting the adopted `WHAT-IF` branch.
   - Execution proceeds to normal review-gated commit.
2. **`REJECT (Rollback & Resume Analysis)`**:
   - The trial modifications are completely discarded.
   - The pre-trial working tree snapshot is restored with 100% fidelity.
   - Session returns to `READ_ONLY_ANALYSIS` mode.
   - The discarded hypothesis is recorded in `settled_facts` / `rejected_hypotheses` to prevent repetitive re-investigation.
   - The assistant outputs the standard decision gate offering next alternative options (Option A, Option B, Option C).

---

## 3. Architecture Transition Model

```
[ Active CRP / Review Gate / Suggested State ]
                    │
                    ▼
       ┌───────────────────────────┐
       │   READ_ONLY_ANALYSIS      │
       └────────────┬──────────────┘
                    │ User Prompt: "ANALYZE WHAT-IF: <Hypothesis>"
                    ▼
       ┌───────────────────────────┐
       │   CREATE PRE-TRIAL        │
       │   BASELINE SNAPSHOT       │
       └────────────┬──────────────┘
                    │
                    ▼
       ┌───────────────────────────┐
       │   TRIAL_IMPLEMENTATION    │
       │   (Alternative Branch)    │
       └────────────┬──────────────┘
                    │ Trial Complete
                    ▼
       ┌───────────────────────────┐
       │   GATE 2 VISUAL REVIEW    │
       │   (Pre-Trial vs Trial)    │
       └──────┬─────────────┬──────┘
    [ACCEPT]  │             │  [REJECT]
              ▼             ▼
┌──────────────────┐   ┌───────────────────────────┐
│ PROMOTE & COMMIT │   │ ROLLBACK PRE-TRIAL STATE  │
│ (Update Parent)  │   │ Return to ANALYZE Mode    │
└──────────────────┘   └─────────────┬─────────────┘
                                     │
                                     ▼
                       ┌───────────────────────────┐
                       │ Explore Alternative (A/B) │
                       └───────────────────────────┘
```

---

## 4. Verification & Acceptance Criteria
- [ ] Command `ANALYZE WHAT-IF` successfully creates an atomic working-tree snapshot before trial edits begin.
- [ ] Control Hub displays an active `WHAT-IF` indicator badge and shows the hypothesis under test.
- [ ] Rejecting a `WHAT-IF` trial cleanly removes all trial changes, restores original pre-trial state, and sets mode back to `READ_ONLY_ANALYSIS`.
- [ ] Accepting a `WHAT-IF` trial promotes the changes and incorporates the rationale into the parent proposal bundle.
- [ ] Sub-path nesting is fenced (max depth = 1).
