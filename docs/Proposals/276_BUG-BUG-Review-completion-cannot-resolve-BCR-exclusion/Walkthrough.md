# Walkthrough: BUG-276 - [BUG] Review completion cannot resolve BCR exclusions

## 1. Executive Summary
Implementation and verification records for BUG-276.

## 2. Verification Evidence
- The helper-scope correction was exercised successfully while completing
  CRP-261 after the original nested helper caused deterministic failure.
- BCR preparation now derives the authoritative rules repository from its
  baseline descriptor and adds it to affected-repository tabs when it has
  durable changes, alongside repositories explicitly declared by the proposal.
- Revision 2 persists those discoveries in the dedicated cross-repository BCR
  obligation ledger. ShowCM renders each unresolved entry as a `COH-<proposal-id>`
  synthetic cohort/Work Queue item immediately after its BUG head and through
  the normal cohort filter, with its ledger reason and normal cohort BCR
  action; it provides no special exact-BCR action.
- BUG-276's Review pending state names the outstanding repository obligations
  and their ledger reason. The normal obligation BCR invocation verifies that
  both `.lcm_review.json` session metadata files are materialized on disk.
- Obligation BCR sessions use a deterministic isolated review identity such as
  `BUG-276_LCM_AI` and session `BUG-276_LCM_AI_Review`, while their metadata
  retains `CRP: BUG-276` for the `BUG-276::LCM_AI` ledger association.
- Primary completion is rejected until all obligation receipts are recorded;
  accepting an obligation BCR resolves only that obligation, not the primary
  proposal.
