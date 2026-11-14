# Walkthrough: CRP-244 - WHAT-IF Analysis Sub-Path Protocol and Trial Implementation Branching

## 1. Overview
Validates the end-to-end lifecycle of a `WHAT-IF` exploratory sub-path: initiating from `READ_ONLY_ANALYSIS`, capturing a baseline snapshot, performing experimental modifications in `TRIAL_IMPLEMENTATION`, and verifying clean rollback upon `REJECT` or promotion upon `ACCEPT`.

---

## 2. Test Scenarios

### Scenario 1: Initiating WHAT-IF Sub-Path
- **Input:** `ANALYZE WHAT-IF: Refactor parser to AST visitor pattern`.
- **Expected:** Engine creates snapshot of working tree, records hypothesis in session state, and transitions mode to `TRIAL_IMPLEMENTATION`.

### Scenario 2: Trial Rejection & Flawless Rollback
- **Input:** Operator reviews trial in Beyond Compare and issues `REJECT`.
- **Expected:**
  - All trial edits are discarded.
  - Pre-trial snapshot is restored with 100% fidelity.
  - Mode switches back to `READ_ONLY_ANALYSIS`.
  - Assistant presents alternative decision gate choices (Option A, Option B, Option C).

### Scenario 3: Trial Acceptance & Promotion
- **Input:** Operator reviews trial in Beyond Compare and issues `ACCEPT`.
- **Expected:**
  - Trial changes are kept.
  - Proposal documentation is amended with rationale.
  - Mode transitions to standard `GOVERNED_IMPLEMENTATION` for review commit.
