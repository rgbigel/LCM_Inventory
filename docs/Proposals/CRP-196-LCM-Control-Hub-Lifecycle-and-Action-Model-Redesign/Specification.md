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
Suggested -> Proceed -> In Progress -> Verify -> Verified -> Commit -> Review Commit -> Completed -> Push -> Pushed
Unborn -> Fast Complete -> Completed -> Push -> Pushed
```

`Commit` stages and creates a local Git commit. `Review Commit` automatically
launches BCompare against the committed delta: the left pane is the local parent
commit and the right pane is the live working tree at the new local commit. The
review is therefore a clean inspection of the proposed committed result, not a
file-selection or staging surface.

The left pane is read-only. Any right-pane modification invalidates the review
receipt, returns the CRP to `in_progress`, and requires verification tests
before a new local commit and a new `Review Commit` cycle. A failed verification
test remains `in_progress`; an unchanged, accepted commit review advances to
`completed`. No invalidated or unreviewed local commit may advance to `push`.

`Open Review` remains a utility action for historic inspection; `Review Commit`
is the automatic lifecycle review. `Request Changes`, `Reopen`, and `Resume`
provide explicit reverse routes. Deferred, blocked, and failed work is
represented by `Held` with a required reason.

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
- Show `Review Commit` with its compared local commit SHAs and disposition;
  expose `Open Review` as a separate historic-inspection tool.
- Move `Clean BCR` into review tools near `Open Review`; keep reset filters in
  the top bar.