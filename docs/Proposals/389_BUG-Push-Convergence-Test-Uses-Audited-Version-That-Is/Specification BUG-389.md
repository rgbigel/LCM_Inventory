# Specification: BUG-389

Module: docs/Proposals/389_BUG-Push-Convergence-Test-Uses-Audited-Version-That-Is/Specification BUG-389.md  
Purpose: Push Convergence Test Uses Audited Version That Is Always Current  
Path: LCM_Inventory/docs/Proposals/389_BUG-Push-Convergence-Test-Uses-Audited-Version-That-Is/Specification BUG-389.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: In Review  
Date: 2026-11-20 16:22:49

```yaml
CRP-ID: BUG-389
Title: Push Convergence Test Uses Audited Version That Is Always Current
Scope: LCM_Inventory
Baseline-Version: 10.8.4
Author: Rolf, Claude
Date: 2026-11-20 16:22:49
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 7
App-ID: None
```

---

## 1. Executive Summary & Intent
Found 2026-11-20 after the 10.8.4 push: Get-LCM_UnconvergedPushRepositories (BUG-380 review item 10) treats a governed repository as converged when inventory CurrentLCMVersion equals the active LCM version; Invoke-LCM_Audit sets 10.8.4 for every governed repository (from the shared baseline), so the next push would push AuthorizeMasterUser, BackgroundModifier, BGMSAMVInv, BootEntryManager, VolumeInventory against the operator rule "do not push if not brought to LCM convergence". Convergence needs a real criterion (operator decision).
- Review: this Specification only (Plan and Walkthrough not written yet).

### Operator One-Time Exception (2026-11-20)

> I think the best way to clean up (at least cost) would be to apply line ending corrections, following the rule
> to ALL repos, governed or not, as an untested correction, and no other changes at all, and mark these repos as
> "OK for PUSH" only once. I do not want to force their convergence to LCMs latest version at this time! So, we
> sidestep the rules for this action only.

State (2026-11-20 16:10:19):
- Line-ending correction applied in all 22 workspace repositories (`Repair-LcmLineEndings.py --apply`): converted
  4 working-tree files in LCM_AI and 30 in LCM_Inventory (tool-written CRLF); no tracked file changed by line ending
  alone (Git normalizes), so no commit; the five held repositories were already clean (their held commits are the
  BUG-365 renormalization of 2026-11-19 plus CRP-369).
- One-time push of AuthorizeMasterUser, BackgroundModifier, BGMSAMVInv, BootEntryManager, VolumeInventory: NOT
  done; the direct `git push` was refused by the Claude Code permission check (raw push outside the governed tool).
  Operator then ordered the push outside LCM ("no hooks can cause a blockage"): pushed 2026-11-20 16:13:59 with
  `git push --no-verify`: AuthorizeMasterUser a032e42, BackgroundModifier 2c50ed5, BGMSAMVInv 8cf1a76,
  BootEntryManager 22abb0f, VolumeInventory 8311626; logged in `cm_activity.log` (PUSH_EXECUTED_EXCEPTION). No
  convergence to 10.8.4 is implied. Operator remark: the line-ending correction was not allowed for non-governed or
  unaligned repositories, but not detrimental.

## 2. Gate 0 Contract (operator option A, 2026-11-20)
### Target State
A governed repository outside the LCM core is never pushed by the governed push unless an explicit convergence
record releases it; the audited version is no evidence. Push bookkeeping is true: nothing ahead is no failure,
the log line carries the active LCM version, GoodMorning reports the real last push.

### Invariants and Exit Criteria
- Non-governed repositories stay plain backup (review item 10).
- Tests: held-by-default case; dry run with nothing ahead exits 0; GoodMorning shows the ledger push time.

### Explicit Non-Goals
- The convergence record itself (comes with the first convergence CRP).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
