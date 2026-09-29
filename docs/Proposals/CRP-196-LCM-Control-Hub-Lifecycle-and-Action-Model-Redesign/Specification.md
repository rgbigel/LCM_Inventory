# CRP-196: LCM Control Hub Lifecycle and Action Model Redesign

```yaml
CRP-ID: CRP-196
Scope: LCM Control Hub and sidecar interaction model
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - Git_Repositories
  - Workspace_Inventory
```

## Objective

Replace inconsistent lifecycle terminology and unreachable status controls with
one explicit lifecycle model and a compact, action-oriented Control Hub.

## Lifecycle Contract

```text
Suggested -> Proceed -> In Progress -> Verify -> Verified -> Commit -> Completed -> Push -> Pushed
Unborn -> Fast Complete -> Completed -> Push -> Pushed
```

`Open Review` is a utility action, not a lifecycle transition. `Request
Changes`, `Reopen`, and `Resume` provide explicit reverse routes. Deferred,
blocked, and failed work is represented by `Held` with a required reason.

## Fast Complete

`Fast Complete` creates a ledger record directly as `completed/completed` for
trivial or critical work. It requires a compact receipt containing the class,
reason, changed files, and focused validation. It is unavailable for semantic
contract, schema, or architectural changes.

## Layout Direction

- Move global App focus to the left of search; it is workspace context, not a
  CRP action.
- Put workspace/version identity in the top-row center.
- Replace the persistent sidecar with an `Actions` dropdown showing only valid
  transitions for the selected proposal or cohort.
- Show the lifecycle rail and shortcuts as separate horizontal rows.
- Move `Clean BCR` into review tools near `Open Review`; keep reset filters in
  the top bar.