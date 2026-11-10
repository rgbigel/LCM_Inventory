# Change Request Proposal: BUG-276

```yaml
CRP-ID: BUG-276
Title: [BUG] Review completion cannot resolve BCR exclusions
Scope: LCM_Inventory
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-14 15:02:17
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Submit-ReviewResult.ps1 defines Test-StandardBcrExcludedPath inside Get-StagedDiffSha256, but invokes it from the acceptance path. Any review manifest containing durable unreviewed paths fails before recording acceptance. Move the helper to script scope and validate the exact BUG review completion path.

## 2. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.
- Invariant 2: An en-route change made outside the originally targeted
  repository, including an immediate correction to an LCM_AI canonical rule,
  must not remain unreviewed. The affected repository must be included in its
  own exact-identity BCR no later than the next BCR cycle.
- Invariant 3: A BCR for one repository does not silently accept durable
  source changes in another repository. Each affected repository requires
  visible review evidence, a receipt, and its normal lifecycle disposition.

## 3. Scope Amendment: Cross-Repository En-Route Changes

The BUG-276 repair must also prevent the workflow error that left an immediate
LCM_AI rule change outside the review evidence for the active repository.

1. Discover durable source changes in all affected workspace repositories when
   preparing or completing a BCR.
2. Keep the current repository BCR exact and bounded; do not silently absorb
   another repository's changes into it.
3. Require the changed repository to be surfaced in its own exact BCR at the
   next BCR opportunity, with the relationship recorded in the originating
   proposal or review receipt.

## 4. Revision 2: Lifecycle-Owned Cross-Repository BCR Obligations

1. BCR discovery shall persist each durable changed repository outside the
   primary repository as an open entry in the dedicated
   `review_obligation_ledger`, linked to the originating proposal.
2. ShowCM shall render every unresolved ledger entry as a normal synthetic
   cohort/Work Queue item named `COH-<proposal-id>` with the originating BUG
   as its head. It shall appear immediately after that head in the active
   sort order, participate in the standard cohort filter (including All
   Cohorts), retain its BCR reason on the cohort row, and use the existing
   normal cohort BCR action; it shall not add a special "Open exact BCR"
   action.
3. The primary proposal's `Review pending` state shall visibly name its
   outstanding repository obligations and provide their discovery reason.
4. Invoking the normal BCR action for an obligation shall recreate missing
   on-disk lifecycle review session metadata before opening Beyond Compare. Its
   isolated review identity shall be `<originating-identity>_<repository>`
   (for example, `BUG-276_LCM_AI`), retaining the ledger association
   `BUG-276::LCM_AI` without overwriting the primary session.
5. Completing that exact repository BCR shall attach its receipt and commit
   evidence to the obligation without completing the primary proposal.
6. A primary proposal cannot transition to `completed` while an unresolved
   cross-repository BCR obligation remains.
7. Cleanup shall use the exact isolated identity as its boundary and shall not
   remove a named BCompare session or scratch bridge while BCompare is active.
