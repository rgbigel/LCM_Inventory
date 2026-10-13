# Change Request Proposal: BUG-262

```yaml
CRP-ID: BUG-262
Title: [BUG] Prevent post-commit lifecycle synchronization failures
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-13 19:50:04
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
CRP-261 Gate 2 completion created commit 10a894b before failing to synchronize the ledger when the proposal omitted cr_id and had not entered in_review. The fix safely matches optional identity fields and requires in_review before any commit.

## 2. Technical Requirements & Invariants

1. Validate exact CRP/BUG identity and lifecycle state before Git staging or commit.
2. Treat `crp_id` and `cr_id` as optional compatibility fields; missing fields must not throw under
   PowerShell StrictMode.
3. Require exactly one matching ledger proposal in `in_review` before completion.
4. Preserve the accepted-review protocol: Beyond Compare left pane is the baseline; completion
   records operator acceptance of the live worktree.
5. Keep CRP-261 completed; BUG-262 owns this post-completion defect repair.
