# CRP-260: Cohort Conflict Analysis and Push Gate

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-260` |
| Lifecycle State | `HELD` |
| Target Scope | Proposal cohort analysis and workspace push gating |
| Impacted Repositories | `LCM_Inventory`, `LCM_AI` |
| Priority | `7` |

## Proposed Semantics

`ANALYZE COMPLETE ALL` and `ANALYZE PUSH ALL` construct a computed cohort, exclude held,
rejected, cancelled, and deferred proposals without failure, and report real Git overlap,
merge, scope, and evidence risks before any lifecycle or publishing operation.

CRP-260 owns the shared cohort-resolution service used by BCR, COMPLETE, and PUSH. A
resolution is either an exact identity, one declared open cohort, a repository scope, or a
bounded computed cohort. It records member identities, repositories, baseline strategy,
classification, broadening reasons, and a stable receipt fingerprint.

When BCR omits a scope, the resolver first selects exactly one declared open cohort. If no
declared cohort exists, it proposes open members in `in_progress`, `verified`, or `in_review`.
The proposal is previewed and requires confirmation whenever scope was omitted or broadened.
It never silently selects a subset: exceeding the configured proposal or repository limit,
conflicting Git-overlap evidence, or incompatible baselines requires explicit selection.

The resolver classifies `in_progress` members as `pending_verification`, `verified` members as
`review_ready`, and `in_review` members as `already_in_review`. It does not change lifecycle
state. CRP-261 consumes this result and remains sole authority for transition validation:
only `review_ready` members may move from `verified` to `in_review`, after their review launch
succeeds.

Declared cohorts use `COH-<prime proposal ID>` naming, for example `COH-261` when CRP-261 or
BUG-261 is the coordinating member. The identifier is stable across the prime member's CRP-to-BUG
reclassification, and the declared `proposal_ids` must include that numeric prime ID. Cohorts are
ledger records with an open/closed state, explicit `proposal_ids`, optional baseline strategy, and
coarse/tight review granularity. They coordinate members but do not replace their individual
histories or create a second lifecycle state.

At most one declared cohort may be open. Operators create it from an explicit selection, add or
exclude members, and close it through Cohort actions in ShowCM or `Invoke-ProposalAction.ps1`.
The first create selection is the prime member and determines `COH-nnn`; it cannot be removed
while the cohort is open. Cross-repository cohort changes require explicit confirmation and the
BCR dispatcher records independent repository baselines.

ShowCM displays each active or held declared cohort with its identifier, state, and members.
Every member row carries its cohort identifier. The Cohort filter composes with the existing
Disposition, Plan State, Status, and Priority filters, so operators can select only eligible
members before using cohort actions. Cohort membership does not change individual lifecycle
action eligibility.

Cohort-resolution receipts are temporary BCR staging material under
`LCM_Inventory/scratch/BC_Review/COH-nnn`, not ledger worktree data. `COMPLETE COH-nnn` validates
that every member is in review, groups members by repository, requires a disposition for unreviewed
paths, commits each repository once, and then advances the successfully committed repository's
members together. A cancelled or failed repository leaves its members in review and reports a
partial outcome without rewriting already committed member history.
