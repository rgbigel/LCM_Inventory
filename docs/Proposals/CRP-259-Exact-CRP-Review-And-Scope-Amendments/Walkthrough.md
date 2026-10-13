# CRP-259 Walkthrough

1. Select one explicit target through `ITEM: CRP-<id>` or `ITEM: COH-<prime>`.
2. Inspect and change persistent Flow Switches only for that target.
3. Use `ACTIONS` to create a `COH-<prime>` from one head/prime CRP (optionally with
   additional members), manage members, or perform lifecycle, document, and FIX operations.
4. Use `Maintenance` for workspace-wide cleanup; it never acts on the current ITEM.
5. Preview cohort membership and terminal disposition changes before confirmation.
