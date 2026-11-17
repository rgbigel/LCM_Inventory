# Specification: CRP-344

Module: docs/Proposals/CRP-344-Run-Beyond-Compare-Non-Elevated-In-BCR/Specification.md  
Purpose: Run Beyond Compare Non-Elevated In BCR  
Path: LCM_Inventory/docs/Proposals/CRP-344-Run-Beyond-Compare-Non-Elevated-In-BCR/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-17 13:40:13

```yaml
CRP-ID: CRP-344
Title: Run Beyond Compare Non-Elevated In BCR
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 13:40:13
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 7
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-17: only the Macrium mount/unmount atoms need elevation; Beyond Compare must run non-elevated. Depends on the intent-level elevation CRP.

## 2. Gate 0 Contract
### Target State
- In BCR only the Macrium mount/unmount atoms (and the AHK dialog atom, CRP-345) run elevated; Beyond Compare itself is always started non-elevated in the operator's Session 1 desktop.
- The BCR intents in `tool_intents` carry `elevated = 0` except those atoms (depends on CRP-343).
- Context (2026-11-17): both open BC windows report `Administrator: _LCM - Folder Compare - Beyond Compare`, because the elevated DO daemon (CRP-309) starts BC; that prefix broke window discovery (second window at 12:17:31).

### Invariants and Exit Criteria
- The writable F: baseline remains usable from the non-elevated BC (left pane edits as review markers, RULE-REV-012).
- `FollowSymLinks`, `_LCM` profile and single-window rule unchanged (RULE-REV-008).
- Exit: a BCR run shows exactly one BC process without `Administrator:` in its title; mount/unmount still succeed; the operator can mark the baseline side.

### Explicit Non-Goals
- Tab location and refresh (CRP-346).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## Absorbed Operator Remarks

Shared operator remark of 2026-11-17, quoted verbatim in CRP-343 `Specification.md`.
