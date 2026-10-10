# CRP-261 Implementation Plan

## Implemented

1. Define `state` as the authoritative lifecycle field and preserve `progress_state` and
   `disposition` as derived compatibility data.
2. Implement the lifecycle transition validator, state history, hold/resume state, dates, and
   action-eligible `ALL` selection in `ProposalManager.psm1`.
3. Route legacy state/progress setters and the main proposal dispatcher through the lifecycle
   authority.
4. Update Control Hub status, counters, rails, timeline, and action availability to use
   authoritative state.
5. Require an exact `CRP-<id>` or `BUG-<id>` for BCR and review-result completion.
6. Define `DOIT`, `-MinimalTests`, `-Force`, `-Immediately`, and per-tool `ADMINMODE`
   boundaries in the specification and operator surfaces.
7. Add focused lifecycle coverage for normal transitions, invalid direct push, documented action
   sets, hold/resume behavior, legacy compatibility mapping, and action-eligible `ALL`.

## Deferred Until Final Reconciliation

1. Run `Get-LcmProposalLifecycleAudit` against the authoritative ledger and classify, rather than
   bulk-rewrite, legacy records and missing bundle metadata.
2. Reconcile the ledger entry and the specification lifecycle header using the audit and review
   evidence.
3. Produce the final before-versus-after comparison and complete the exact-identity Gate 2 BCR
   for `CRP-261`.
4. Decide whether to restore LCM mode from `paused` to `active` only after Gate 2 acceptance.
