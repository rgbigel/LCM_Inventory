# CRP-261 Walkthrough

## Revision 2 Reopen

- 2026-10-14: Explicitly reopened from `completed` to `in_progress` to correct
  ShowCM action ordering, push/publication ledger visibility, original-source
  editing, receipt/history access, Mermaid-capable document preview, and
  terminal-CRP reinstatement.
- ShowCM now displays `Reinstate Revision` only for `completed` and `pushed`
  CRPs. Its modal separates an optional revision note from concrete correction
  requests: blank requests return the CRP to `suggested`; nonblank requests
  return it to `in_progress` for focused verification and exact-identity BCR.
- Focused lifecycle and Control Hub validation passed; Gate 2 BCR acceptance
  remains pending.

## Delivered Lifecycle Authority

The proposal lifecycle now has one authoritative internal field:

```text
suggested -> in_progress -> verified -> in_review -> completed -> pushed
```

The exception and terminal states are `held`, `withdrawn`, `rejected`, and `superseded`.
`progress_state` and `disposition` remain derived compatibility data and do not determine
transition availability.

`ProposalManager.psm1` validates transitions, records state history and timestamps, retains a
proposal's `resume_state` while held, and limits `ALL` to proposals that are eligible for the
requested transition.

## Operator Flow

1. `DO` starts a suggested proposal and enables its continuous-flow marker.
2. `VERIFY` transitions an in-progress proposal to `verified`.
3. `BCR` requires the exact CRP or BUG identifier, launches the review path, and enters
   `in_review` only after the BCR handoff.
4. `COMPLETE` or `COMMIT` uses the exact-identity review-result path to enter `completed`.
5. `PUSH` transitions eligible completed proposals to `pushed` only after push processing succeeds.

`PROCEED` is intentionally limited to safe pre-review progression and cannot bypass BCR,
completion, or push.

## Switch Boundaries

- `DOIT` does not bypass BCR, completion, push, or terminal-state restrictions.
- `-MinimalTests` records a reduced completion/review test scope but does not waive identity or
  final-review requirements.
- `-Force` is limited to an authorized interactive visual-review confirmation exception.
- `-Immediately` is a documented emergency quality-check deferral. A single CRP target is
  reclassified as `BUG-<id>` only when this switch is invoked, retaining its original CRP identity
  in audit metadata. A multi-proposal cohort must explicitly include a BUG. It requires details
  and ends at the BCR handoff.
- Tool `ADMINMODE` is a per-tool elevation design criterion. Turning it off records a redesign
  decision and does not remove existing elevation code automatically.

## Evidence

- `ProposalLifecycle.Tests.ps1`: 7 passing tests.
- PowerShell AST parsing passed for the lifecycle authority and dispatch/review/completion tools.
- Embedded Control Hub scripts parse successfully.
- Missing-CRP guard checks confirm BCR and review-result completion reject repository-only
  inference.

## Remaining Final Gates

LCM remains paused. The ledger audit and lifecycle-header reconciliation are deliberately deferred
until immediately before the exact-identity Gate 2 BCR for `CRP-261`. Gate 2 acceptance is
required before deciding whether to restore LCM mode to active.
