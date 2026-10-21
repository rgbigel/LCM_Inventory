# Change Request Proposal: CRP-281

```yaml
CRP-ID: CRP-281
Title: Primary Evidence-Based Workspace Readiness and Passive Legacy Checks
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-16 20:05:24
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Goal
Make internal progress faster and more reliable by evaluating the exact CRP
goal and affected surfaces through scoped evidence for documentation, rules,
flow, and implementation detail.

## 2. Documentation Area
- CRP bundle, applicable rules, tool contracts, lifecycle evidence, and
  affected source/test documentation are assembled before evaluation.
- Discrepancies become named design inputs with an owner and proposed
  resolution; they are not generic terminal blocks.

## 3. Requirements
- Emit a CRP-scoped, fingerprinted evidence receipt with evidence links.
- Use current required evidence as the primary internal progress authority.
- Classify legacy broad checks as primary, passive, or retired.
- Passive checks report health without advancing or blocking ordinary design
  progress and without mutating workspace state.

## 4. Non-Goals
- Do not remove legacy checks before replacement coverage is demonstrated.
- Do not let an AI/model output decide lifecycle state without deterministic
  evidence.
