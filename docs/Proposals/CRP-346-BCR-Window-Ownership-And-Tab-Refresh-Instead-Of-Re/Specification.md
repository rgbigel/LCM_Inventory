# Specification: CRP-346

Module: docs/Proposals/CRP-346-BCR-Window-Ownership-And-Tab-Refresh-Instead-Of-Re/Specification.md  
Purpose: BCR Window Ownership And Tab Refresh Instead Of Relaunch  
Path: LCM_Inventory/docs/Proposals/CRP-346-BCR-Window-Ownership-And-Tab-Refresh-Instead-Of-Re/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-17 13:40:15

```yaml
CRP-ID: CRP-346
Title: BCR Window Ownership And Tab Refresh Instead Of Relaunch
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 13:40:15
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-17: BCR recognises the BC window it started, locates the _LCM tab (AHK atom) and refreshes it instead of opening another window. Depends on the non-elevated BC and AHK atom CRPs.

## 2. Gate 0 Contract
### Target State
- BCR records the BC window it starts (process ID, window handle, start time, review identity) and later recognises it by that record, not by window title.
- When such a window is open and the baseline is mounted, BCR does not launch another window: it locates the `_LCM` tab (tab names through the CRP-345 tab atom), activates it and performs a Full Refresh.
- Context (2026-11-17 probe): window titles show only the active tab; UI Automation and MSAA expose the tab strip but no tab names; each tab is one `TDirCompareView` child window (count and active tab readable).

### Invariants and Exit Criteria
- Operator windows and tabs that BCR did not start are never closed or retitled (RULE-REV-012); existing tabs are preserved.
- A remount (newer image) still triggers a refresh of the recorded window, not a relaunch.
- Exit: two consecutive BCR runs on a mounted baseline leave exactly one BC window; the second run refreshes the `_LCM` tab; works with another tab active.

### Explicit Non-Goals
- Post-mount image identity verification (convergence/BCR follow-up, 2026-11-17 question).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## Absorbed Operator Remarks

Shared operator remark of 2026-11-17, quoted verbatim in CRP-343 `Specification.md`.
