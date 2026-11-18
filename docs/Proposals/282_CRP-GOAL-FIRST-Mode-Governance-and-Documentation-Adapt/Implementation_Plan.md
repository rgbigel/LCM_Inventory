# Implementation Plan: CRP-282 - GOAL-FIRST Mode Governance and Documentation Adaptation

Idea: try this as a starter and then check if it converges with the #4 and #5 below:
# Architectural Operating Invariant: Goal-First Execution

## 1. Anti-Pattern Prohibition (No Reactive Patching)
- DO NOT engage in symptom repair, local code patching, or ad-hoc troubleshooting 
  unless an explicit Target State Definition has been established and verified.
- If an error, friction, or new feature request is presented, treat the presentation 
  merely as a symptom, not the assignment.

## 2. Mandatory Gate 0: Target State Specification
Before proposing any structural modification, architecture design, or implementation steps, 
you must emit a "Gate 0 Contract" containing:
1. Target State (The Goal): Exactly what must be true when this task is complete.
2. Invariants & Exit Criteria: Observable, testable proof that the goal is reached.
3. Explicit Non-Goals: What is deliberately out of scope to prevent lateral creep.

## 3. Enforcement & Verification
- If Gate 0 is missing, halt execution and request confirmation of the Target State.
- Every subsequent design step or code generation must cite which part of the Target State 
  it directly serves. If an action cannot trace back to the goal, discard it.

## 4. Design Cycles
1. Add the canonical GoalFirstDesignPolicy.
2. Amend analysis policy from halt-first to design-refinement behavior.
3. Amend proposal, documentation, efficiency, review, and authority policies.
4. Synchronize AGENTS.md and the rules cross-reference.
5. Add durable accepted guidance and CRP bundle sections.
6. Test that goal/discrepancy/candidate output is required without weakening
   implementation or publication safeguards.

## 5. Verification
- Parse every changed policy and discovery document.
- Verify all new rule IDs appear in both discovery matrices.
- Verify existing review, acceptance, and publication gates remain unchanged.
