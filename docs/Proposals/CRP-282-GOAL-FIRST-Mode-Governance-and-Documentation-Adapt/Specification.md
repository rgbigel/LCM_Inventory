# Change Request Proposal: CRP-282

```yaml
CRP-ID: CRP-282
Title: GOAL-FIRST Mode Governance and Documentation Adaptation
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-10-16 20:05:25
Status: Accepted (Specification)
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Goal
Make GOAL-FIRST MODE a workspace invariant: every CRP, BUG, correction, and
analysis starts from the documented goal and flows through iterative candidate
design cycles until implementation readiness.

## 2. Gate 0 Contract
### Target State
Every structural proposal and governed analysis has an explicit goal, measurable
exit criteria, and non-goals before implementation begins. Policy discrepancies
produce the next traceable design cycle rather than a reactive patch or an
unexplained halt.

### Invariants and Exit Criteria
- Goal-First work preserves proposal-first intake, verification, Gate 2 BCR,
  commit, and publication requirements.
- Each implemented candidate identifies the target-state clause it serves.
- The canonical policy and every discovery entrypoint identify the same rule IDs.

### Explicit Non-Goals
- This CRP does not disable governance, BCR, review, commit, or publication gates.
- This CRP does not make every incidental operator question a structural change.
- Ordinary, evidently scoped BUGs and CRPs may use the implicit Non-Goal:
  **Cause no havoc: ask rather than invent or infer, and avoid unnecessary
  complexity.**

## 3. Requirements
- Assemble a Documentation Area from the CRP first, then relevant supporting
  documents, rules, tools, and prior decisions.
- Treat documentation gaps, rule tensions, and ledger discrepancies as named
  design inputs with causes, owners, and proposed repairs.
- Require every analysis to propose the next useful design cycle.
- Reserve `blocked` for unsafe or unauthorized execution impossibility.
- Preserve hard implementation, review, commit, and publication safety gates.
- Do not reject an ordinary BUG or CRP solely because separately written
  non-goals are absent when its target is evident and the implicit Non-Goal applies.

## 4. Impacted Governance
- New GoalFirstDesignPolicy.
- Analysis, proposal-flow, documentation, efficiency, review/commit, and rule
  authority policy amendments.
- Rule discovery matrix, durable learned advice, and CRP documentation updates.

## 5. Specification Acceptance
Accepted by the operator on 2026-10-17. This Specification is the authoritative
CRP-282 contract. `Implementation_Plan.md` and `Walkthrough.md` are
supplementary design and evidence records.
