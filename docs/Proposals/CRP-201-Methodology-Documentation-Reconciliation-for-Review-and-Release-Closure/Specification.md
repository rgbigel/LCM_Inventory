# CRP-201: Methodology Documentation Reconciliation for Review and Release Closure

```yaml
CRP-ID: CRP-201
Priority: High
Scope: LCM_AI methodology and governance documentation
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - LCM_AI
```

## Objective

Reconcile the Lifecycle Model methodology with the operating reality of
incremental implementation, visual review cycles, operational records, and
release closure. The documentation must preserve the distinction between
visual-review scope and tracked operational evidence without defining the
unresolved lifecycle state transitions or Control Hub actions.

## Requirements

1. Define the boundary between BCompare visual-review scope and tracked
   operational evidence. BCompare filters decide visual materiality; they do
   not determine whether a tracked operational file is legitimate.
2. Record that `data/`, `logs/`, review receipts, inventories, and other
   operational artifacts may be changed or uncommitted during legitimate
   prototyping, testing, and release preparation. Their presence alone is not
   a defect or an unreviewed-source candidate.
3. Define the proposal ledger and activity logs as append-oriented operational
   records. Do not require routine lifecycle bookkeeping to be visually
   reviewed as source code.
4. Define documentation reconciliation as a required release-closure activity,
   no later than a major-version push. It is not required to be perfectly
   current after every intermediate review cycle.
5. Document that proposal bundles and review walkthroughs may carry provisional
   knowledge until it is synthesized into authoritative methodology documents.
6. Preserve historical log cleanup and retention mechanisms as maintenance;
   they must not be described as history rewriting or evidence forgery.

## Non-Goals

- No changes to `LCM_Inventory` tools, review filters, commit behavior,
  or push behavior.
- No definition, correction, or documentation of lifecycle state transitions,
  commit timing, or Control Hub actions. CRP-196 owns that unresolved design.
- No retroactive normalization of proposal or log history.
- No claim that every existing implementation already conforms to the clarified
  methodology.

## Target Documents

- `LCM_AI/docs/Architecture.md`
- `LCM_AI/docs/Requirements.md`
- `LCM_AI/docs/Implementation.md`
- `LCM_AI/docs/LCM-Configuration-Management.md`