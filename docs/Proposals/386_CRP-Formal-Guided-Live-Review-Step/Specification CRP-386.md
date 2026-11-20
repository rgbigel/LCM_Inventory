# Specification: CRP-386

Module: docs/Proposals/386_CRP-Formal-Guided-Live-Review-Step/Specification CRP-386.md  
Purpose: Formal Guided Live Review Step  
Path: LCM_Inventory/docs/Proposals/386_CRP-Formal-Guided-Live-Review-Step/Specification CRP-386.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-20 12:01:10

```yaml
CRP-ID: CRP-386
Title: Formal Guided Live Review Step
Scope: LCM_Inventory, LCM_AI
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-20 12:01:10
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator 2026-11-20: "I liked the live review we did yesterday. Produce a suggested CRP that shall provide a
methodological and tool-assisted review step that works in a similar, but formal way."

The model is the CRP-361 live test (2026-11-19 23:48 .. 2026-11-20 00:20, `Walkthrough CRP-361.md` section 3):
the AI proposed numbered steps one at a time in the chat, the operator ran each in his own terminal or display
and answered with the result; the AI recorded each answer (passed / finding) and moved findings into a ticket
(BUG-380 B1-B11). It worked because each step was small, concrete and run by the operator in his real environment;
it was informal because the steps were invented ad hoc, results lived only in the chat until written up, and
nothing tied the test to the Gate 0 exit criteria.

Learned advice binding here: "Gate 2 Pre-Review Live Testability Invariant" (2026-11-13) and "operator live tests
are guided in the chat ... the Walkthrough documents the (guided) live test results" (2026-11-18).

- Review: this Specification only.

## 2. Gate 0 Contract

### Target State

1. **Live test script per item**: before Gate 2 the AI writes the live test steps into the bundle
   (`Specification` section "Live Test", or the Implementation Plan when it goes beyond the Specification): number,
   action (exact command or display path), expected result, Gate 0 clause served (RULE-GOAL-004).
2. **Guided run**: a tool (working name `Invoke-LcmLiveReview`) presents one step at a time to the operator,
   records the operator's answer (`passed` / `failed` / `skipped` / note), timestamp and environment (host,
   terminal or display), and stops after a failed step until the operator decides (continue / fix now / defer).
3. **Recording**: results land in a ledger table (`live_review_steps` in `proposals.db`, with `.sql` projection;
   SQL dump before the table change) and are rendered into the `Walkthrough` section "Operator Live Test";
   no hand-written result table.
4. **Findings**: a failed step creates or extends a ticket through the governed function (learned advice B1/B2:
   add to the item being processed or an open collector such as BUG-380), linked to the step.
5. **Gate link**: Gate 2 (BCR) for an item with a live test script requires a completed live review
   (all steps passed, or failures dispositioned by the operator); the BCR receipt names the live review run.
6. **Chat mode stays**: the AI may still guide in the chat; the tool is the record and the order, not a
   replacement of the conversation.

### Invariants and Exit Criteria

- Steps are run by the operator in his environment; the AI never marks a step `passed` itself.
- Exit: one real item (first candidate: BUG-380 B12 or CRP-385) reviewed end to end with the tool; Walkthrough
  generated; failed step produced a linked ticket entry.

### Explicit Non-Goals

- No automated UI testing (the AI's own pre-tests stay separate, D-24).
- No change to the BC5 visual review itself (RULE-REV-014).

## 3. Open Decisions

- Where the guided run lives: chat-only with a recording tool (A), a small display page on port 9876 (B), or both (C).
