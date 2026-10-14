# Change Request Proposal: BUG-276

`yaml
CRP-ID: BUG-276
Title: [BUG] Review completion cannot resolve BCR exclusions
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-14 15:02:17
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
`

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
