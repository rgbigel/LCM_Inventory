# Implementation Plan: CRP-284 - Macrium BCR Foreground and Retired Staging Removal

## 1. Design Steps
1. Trace all callers of `Clear-BCReviewTemp.ps1`, its generated launcher, and
   associated tool-catalog records before retiring it.
2. Remove the unapproved environment guard rather than making it permanent.
3. Extend the daemon foreground contract with an explicit `refresh: false`
   option and call it from the existing-review branch in
   `Invoke-MacriumDailyBcrBaseline.ps1`.
4. Surface the exact BCR scope in the Control Hub active-review presentation.
5. Restore the user-facing `BCR` Tool Catalog ReviewGate entry for
   `Invoke-MacriumBcrReview.ps1`.
6. Amend LCM_AI switch policy and LCM_Inventory contracts so non-default
   `DOIT`, `FIX`, and `IMMEDIATELY` behavior is explicit, operator-authorized,
   visible, and never inferred.
7. Define component patch-version advancement for substantive behavior or
   authoritative-documentation corrections.
8. Add focused tests for foreground dispatch, no refresh key injection, scope
   display, catalog routing, switch visibility, and absence of retired staging
   creation.
9. Use the operator-reviewed D: worktree as forward-only evidence; do not
   reset it to recreate the retired review design.

## 2. Acceptance Evidence
- Focused Pester tests pass.
- A daemon-backed existing-window BCR reports successful foreground activation
  without refresh.
- Control Hub output identifies the active review CRP/BUG or cohort.
- Tool Explorer exposes `BCR` as a user ReviewGate for the Macrium flow.
- Static search finds no executable legacy staging or cleanup entry point.
- Rule and documentation headers have patch increments where required.
