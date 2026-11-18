# CRP-259 Implementation Plan

1. Add backend proposal retirement and supersession actions with successor validation,
   relationship persistence, and focused tests.
2. Refactor the Control Hub top strip around one explicit `ITEM: CRP-<id> | COH-<prime>`
   target, Flow Switches, FIX, and Maintenance controls. No switch or action may infer a
   target from a row, prior selection, or visible-item fallback. A row action must first
   switch ITEM explicitly to that row's CRP or COH target.
3. Replace the row `SHOW` menu with grouped `ACTIONS` menus for target operations,
   lifecycle actions, cohort membership, documents, and FIX actions. When ITEM is a COH,
   every selected cohort action resolves the cohort's complete current membership at action
   time; it must not operate on a cached, partial, or row-derived member set.
4. Remove the lower workspace and relocate its lifecycle visibility to an item action.
   Keep workspace maintenance separate from ITEM-targeted actions.
5. Add a head/prime-based cohort membership editor. A cohort identity is `COH-<prime>`,
   where `<prime>` is its head/prime CRP. A valid cohort may contain only that head/prime;
   additional CRPs are optional. Membership proposals preview additions and removals, then
   atomically validate and persist the complete change: the prime cannot be removed or
   replaced, every member must be in the same repository, and duplicate members are rejected.
6. Enforce the backend cohort-state invariant immediately before persistence: at most one
   active/open cohort exists, while any number of inactive/closed cohorts may exist. Creating
   a cohort while another is active/open creates the new cohort inactive. Activating/opening
   an inactive cohort fails if another cohort is open. `Add` has no cohort selector: it
   automatically targets the sole active/open cohort and displays its identifier read-only;
   if no cohort is active/open, it fails with a clear no-active-cohort error.
7. Make cohort lifecycle actions atomic across all resolved current members, including a
   valid sole head/prime cohort. Validate every member before mutation; an ineligible member
   rejects the action with its member-specific reason and leaves every member unchanged.
8. Remove the old selection-driven bulk-action behavior from the interface. Amend
   ProposalReviewFlowPolicy with explicit ITEM identity, complete-member cohort resolution,
   atomic cohort action, and FIX presentation invariants while retaining the distinct Force
   and Immediately mechanics. `DOIT` remains a flow gate; it is not authority to force an
   unsafe lifecycle mutation or bypass cohort validation, atomicity, or review prerequisites.
9. Implement automatic active/open-cohort gate synchronization at Gate 1, verification, BCR,
   and completion. Before continuation, resolve every current member and validate the shared
   required state using only existing validated evidence and required preconditions. Fail
   closed with member-specific errors: do not begin BCR and do not partially advance any
   member if alignment or verification fails. Record synchronization, evidence/precondition
   checks, no-op-already-aligned outcomes, and the result in audit metadata.
10. At BCR Gate 2, initiate one BCR for the exact resolved cohort scope only after every
    member is aligned. All members must have a recorded disposition for that scope before
    continuation; reject continuation otherwise, except through an explicit authorized BCR
    bypass. Do not initiate BCR at the planning gate. `-Force` and `-Immediately` remain
    distinct mechanisms and do not imply a BCR bypass.
11. Validate target identity and row-to-ITEM switching, single-head creation, no-active Add
    rejection, membership validation and atomicity, sole-open lifecycle transitions, complete
    cohort resolution and atomic lifecycle actions, gate synchronization and BCR disposition
    enforcement, retirement, supersession, HTML behavior, PowerShell AST syntax, and focused
    tests.
