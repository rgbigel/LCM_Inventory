# Change Request Proposal: CRP-284

```yaml
CRP-ID: CRP-284
Title: Macrium BCR Foreground, Review Catalog, and Lifecycle Traceability
Scope: LCM_AI and LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-17
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Goal
Make the active Macrium BCR flow visibly and reliably present the exact pending
review in the foreground, while removing all remaining legacy Git-export,
junction-staging, and unapproved cleanup-switch behavior. Preserve the
operator-reviewed current D: state as the baseline for advancement rather than
rewinding it to an earlier repository state.

## 2. Confirmed Current State
- `Invoke-ProposalAction.ps1 -Action bcr` calls `Invoke-MacriumBcrReview.ps1`.
- `Invoke-MacriumDailyBcrBaseline.ps1` opens `_LCM` when no review window
  exists, but merely reuses an existing `_LCM` window without foregrounding it.
- The desktop daemon already provides a foreground operation, but currently
  refreshes the activated window by default.
- The retired `Clear-BCReviewTemp.ps1` contains an unapproved
  `LCM_DISABLE_BC_REVIEW` environment guard.
- The former `BCR` catalog role was removed with the old launcher and was not
  replaced by a user-facing Macrium BCR catalog entry.

## 3. Requirements
1. A successful BCR action that finds an existing `_LCM` review window MUST
   activate that exact window without sending a review-altering refresh.
2. The Control Hub MUST expose the exact CRP/BUG or resolved cohort scope
   associated with an active review.
3. A review launch or foreground failure MUST be explicit and MUST NOT be
   represented as an active review.
4. The unapproved `LCM_DISABLE_BC_REVIEW` environment switch MUST be removed.
5. The legacy BC scratch cleanup utility MUST be retired only after its direct
   callers and generated launchers are removed or replaced.
6. No BCR path may create `BC_Review_Temp`, `Live_*`, `ACTIVE_LIVE`, or a
   live-directory junction.
7. The Tool Catalog MUST retain a user-facing `BCR` ReviewGate command that
   targets `Invoke-MacriumBcrReview.ps1` and requires an exact CRP/BUG scope.
8. Current D: working-tree changes reviewed and commented on by the operator
   are the forward-only correction baseline. They MUST NOT be reset or
   rewritten merely to reproduce a prior state.
9. AI execution MUST NOT infer or enable a non-default flow switch. Only
   explicit operator `DOIT`, `FIX`, or `IMMEDIATELY` expressions may request
   their corresponding non-default behavior.
10. `FIX` and `IMMEDIATELY` MUST remain exact-identity, critical-case
    mechanisms; only `fix` may bypass Gate 2 review.
11. A real behavioral or authoritative-documentation correction MUST advance
    its affected component version by patch while preserving major parity.
12. Publish normal, change/re-entry, and emergency/switch code-traversal
    diagrams with unchanged internal paths collapsed.

## 4. Non-Goals
- Do not create or remount a Macrium baseline outside the current BCR contract.
- Do not alter the operator-owned `_LCM` comparison profile paths.
- Do not accept, complete, commit, or push any proposal automatically.
