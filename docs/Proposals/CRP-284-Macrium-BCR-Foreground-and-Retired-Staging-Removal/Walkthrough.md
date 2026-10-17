# Walkthrough: CRP-284 - Macrium BCR Foreground and Retired Staging Removal

## 1. Current Status
Suggested. No CRP-284 implementation has started and no BCR has been launched
for this proposal.

## 2. Pre-Implementation Evidence
- The active lifecycle BCR caller is `Invoke-ProposalAction.ps1`.
- The active BCR wrapper is `Invoke-MacriumBcrReview.ps1`.
- Existing `_LCM` windows are reused without foreground activation.
- `LCM_DISABLE_BC_REVIEW` is an uncommitted, unapproved local insertion.
- CRP-266 is completed and does not own this correction.
- CRP-285 was created during initial scoping, then consolidated into CRP-284
  before implementation because one BCR review scope is clearer.

## 3. Required Review Scope
The eventual BCR must identify CRP-284 explicitly and cover the daemon,
Macrium BCR, Tool Catalog, Control Hub, cleanup retirement, switch policy,
versioning, lifecycle charts, tests, and directly related documentation.
