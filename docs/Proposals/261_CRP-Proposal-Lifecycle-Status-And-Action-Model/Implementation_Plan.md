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

## Revision 2: ShowCM Correction Plan

1. Reopen CRP-261 as `in_progress` with a forward-only revision event.
2. Reorder the row ACTIONS groups and Documents actions without changing the
   semantics of the remaining groups.
3. Inject retained review receipts when compiling the Control Hub artifact and
   resolve them by explicit ledger path, CRP identity, or recorded commit.
4. Resolve Documents/Edit to the original proposal source before any
   specification fallback.
5. Add safe visual document preview with Mermaid rendering and a source
   fallback when rendering is unavailable.
6. Expose terminal-CRP reinstatement in ShowCM, with separate revision-note
   and concrete-correction inputs so the UI preserves the two governed
   reinstatement outcomes.
7. Add focused Control Hub regression assertions and run artifact-generation,
   JavaScript syntax, and focused Pester validation.
