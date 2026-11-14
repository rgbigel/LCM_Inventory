# Walkthrough: CRP-243 - Integration of Read-Only Analysis Protocol & Implementation Gating into Workspace Governance

## 1. Overview
This walkthrough validates the end-to-end lifecycle of the Read-Only Analysis Protocol and its integration with the LCM Control Hub and governance rules.

---

## 2. Test Scenarios & Expected Outcomes

### Scenario 1: `ANALYZE` Wake Word Activation
- **Input:** User prompt begins with `ANALYZE: <Task Description>`.
- **Expected Behavior:**
  - AI switches internal mode to `READ_ONLY_ANALYSIS`.
  - Emits 4-part structured response:
    1. Structured Model (Entities, Variables, Actions, Constraints).
    2. Evidence table citing `[VERIFIED: <file#line>]` or `[GAP: <item>]`.
    3. State Delta.
    4. Decision Gate with 2–3 explicit choices (A, B, C).
  - AI executes zero file modifications or code edits.

### Scenario 2: Implementation Guard in Analysis Mode
- **Condition:** Session is in `READ_ONLY_ANALYSIS`.
- **Action:** A tool call or script tries to run `replace_file_content` or `git commit`.
- **Expected Behavior:** Action is rejected with explicit governance error: `GOVERNANCE BLOCK: Modifications are disallowed while in READ_ONLY_ANALYSIS mode`.

### Scenario 3: `IMPLEMENT` Mode Transition
- **Input:** User prompt issues `IMPLEMENT: <Selected Option>`.
- **Expected Behavior:**
  - Session transitions to `GOVERNED_IMPLEMENTATION`.
  - State registers update (`LCM_OperatingMode = GOVERNED_IMPLEMENTATION`).
  - Standard LCM implementation and review gating proceed.

### Scenario 4: Circuit Breaker Interruption
- **Condition:** In `GOVERNED_IMPLEMENTATION`, an unexpected missing API parameter or contradictory specification is discovered.
- **Expected Behavior:**
  - Execution immediately halts without guessing or speculating.
  - Session transitions to `CIRCUIT_BREAKER_HALT`.
  - Output formats header `### [ANALYSIS RESUMED] - Implementation Block Encountered` with Gap/Conflict, Invalidation rationale, and Decision Gate choices.
  - LCM Control Hub alerts operator to the circuit breaker halt.
