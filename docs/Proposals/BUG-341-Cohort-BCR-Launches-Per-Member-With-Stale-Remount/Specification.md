# Specification: BUG-341

Module: docs/Proposals/BUG-341-Cohort-BCR-Launches-Per-Member-With-Stale-Remount/Specification.md  
Purpose: Cohort BCR Launches Per Member With Stale Remount  
Path: LCM_Inventory/docs/Proposals/BUG-341-Cohort-BCR-Launches-Per-Member-With-Stale-Remount/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: In Progress  
Date: 2026-11-17 12:03:50

```yaml
CRP-ID: BUG-341
Title: Cohort BCR Launches Per Member With Stale Remount
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-16 21:51:03
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 7
App-ID: None
Severity: High
Root-Cause: Per-member BCR launch in Invoke-ProposalAction bcr; baseline currency judged by the newest lcm-internal log inside the image instead of the mounted image identity.
```

---

## 1. Executive Summary & Intent
Invoke-ProposalAction -Action bcr COH-331 (6 members) ran one BCR per member instead of one joint cohort BCR (RULE-LCM-002): 6 remounts of the same 07-07 image and 6 Beyond Compare windows within 6 min. Staleness check compares snapshotSaved 2026-11-14 22:37:12 instead of the mounted image date, so F: is always stale (RULE-REV-012). Members were not moved to in_review.

Correction (2026-11-17, Claude, from the run logs): the staleness decision does not use `snapshotSaved`; that value is only logged as mount evidence. The decision uses the newest `LCM_Inventory\data\logs\lcm-internal\*.log` inside the mounted image (`Find-MountedMacriumBaselineCandidates`, `NewestLogDate`). In the freshly mounted 07-07 image that log dated 2026-11-14 17:40:55, 39.4 h before the image completed (2026-11-16 09:07:27); the rule "same date or at most 36 h" therefore judged today's own image stale on every call.

## 2. Gate 0 Contract
BUG: the target state is inherent in the defect (RULE-GOAL-002); DOIT to Gate 2.

### Target State
- A `bcr` action on a declared cohort opens exactly one joint BCR: at most one baseline mount and one `_LCM` Beyond Compare window, independent of `review_granularity` (RULE-LCM-002).
- An already mounted baseline that is today's completed image is reused (fast path), never remounted (RULE-REV-012).

### Invariants and Exit Criteria
- Every cohort member still gets its review metadata (`scratch/BC_Review/<ID>/.lcm_review.json`) and moves to `in_review`.
- Non-cohort `bcr` keeps its existing per-granularity behaviour.
- A newer completed image than the mounted one still triggers a remount (RULE-REV-012).
- Exit: parse gate clean; `MacriumBcrReview.Tests.ps1` 100 %; live joint BCR of COH-331 shows one mount and one BC window (operator Gate 2 test).

### Explicit Non-Goals
- The suspected F: lock that prevents dismount: not reproduced (every detach in the 2026-11-16 21:43-21:49 logs succeeded); reopen as its own BUG when it recurs.
- Window title carries the first member identity, not the cohort ID (`Invoke-MacriumBcrReview.ps1` accepts only CRP/BUG IDs).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.
- Invariant 2: The identity check trusts the registry values written by the tool's own mount (`HKLM:\SOFTWARE\LCM\MacriumBaseline` `MRMImagePath`, `MRMdrive`); a manual mount on the same drive letter outside the tool is not detected (`-NewBaseline` remains the override).
