# Specification: BUG-348

Module: docs/Proposals/348_BUG-Defects-Found-2026-11-17-Daemon-Gaps-Rule-Health-T/Specification BUG-348.md  
Purpose: Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks  
Path: LCM_Inventory/docs/Proposals/348_BUG-Defects-Found-2026-11-17-Daemon-Gaps-Rule-Health-T/Specification BUG-348.md  
Authors: Rolf, Claude  
Version: 10.6.4  
Status: In Review  
Date: 2026-11-18 15:57:30

```yaml
CRP-ID: BUG-348
Title: Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-18 15:57:30
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Collected defects found 2026-11-17 (operator: own BUG, preferably one): (1) Go daemon port gaps: pages call /set_priority, /query_all_short_names, /print, /abort, which src/do does not register (fall to "/", POST -> 405). (2) Read-only display routes send Access-Control-Allow-Origin * (foreign pages can read displays, proposals, logs). (3) Test-LCMRuleHealth.ps1 reports Static Rule Copies for every child repo: it checks <repo>\.agents\rules, the junction is <repo>\.agents since BUG-338 (false positive). (4) ProposalLifecycle.Tests.ps1: 3 failures (transition table held, missing logs/history/cm_activity_v5_v6_history.log, hold state blocked vs held). (5) Scheduled task \LCM_Daemon_InteractiveStarter has a malformed action path (\ ...do.exe daemon\). (6) BCR post-mount check does not verify the mounted image identity (only volume label + Git_Repositories folder); registry MRMImagePath is written from the requested image. (7) gofmt deviations in src/do client.go, main.go, types.go, winutil.go. (8) do.exe status/version report a hard-coded 10.2.0.

- Review: this Specification and the Walkthrough (two findings are not fixed: one is a decision for the operator, one is deliberately on hold).

## 2. Gate 0 Contract
### Target State
Segment 1 (PowerShell, 2026-11-18):
- S1 `Invoke-LCM_Push.ps1 -DryRun` changes nothing: no export commit, no catalog commit, no maintenance deletion (merged item a).
- S2 The Control Hub Maintenance button runs the existing `Invoke-LCM_Maintenance.ps1` after its confirmation dialog (merged item c).
- S3 `Test-LCMRuleHealth.ps1` reports a child repository whose `.agents` is a junction to `LCM_AI\.agents` as in compliance (item 3).
- S4 `ProposalLifecycle.Tests.ps1`: the history-log failure (test mock reached the real render) and the hold progress value (`blocked`) are fixed (item 4, two of three).
Segment 2 (Go daemon, with the operator present, because the daemon is rebuilt and redeployed): items 1, 2, 5, 6, 7, 8.

### Invariants and Exit Criteria
- Parse gate; `ProposalLifecycle` without the two fixed failures; rule health run shows every repository in compliance; a push dry run leaves `git status` of all governed repositories unchanged.

### Explicit Non-Goals
- Merged item b (bundle purge at push): deliberately on hold by operator decision D-31 (bundles are kept until absorbed into the baseline docs); not a defect.
- Tightening the lifecycle transition table (decision, see Walkthrough).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
## Merged Findings

- [merged 2026-11-18 15:53:44] From the CRP-355 analysis 2026-11-18 (operator choice 1.1): (a) Invoke-LCM_Push.ps1 calls Invoke-LCM_Maintenance a second time (around line 301, "-TailLines 100") without the -DryRun/-LogOnly guard, so a push dry run deletes script logs and junk (cause of the 186 deleted logs); (b) Invoke-LCM_Push does not purge pushed bundles (Remove-LcmProposalBundle is only reachable via purge-bundle), contrary to RULE-LCM-020, 130 pushed bundles remain; (c) the Control Hub Maintenance button calls Invoke-WorkspaceMaintenance.ps1, which does not exist.

- [merged 2026-11-18 23:11:44] Found 2026-11-18 23:05 (BCR for CRP-332 refused): Invoke-MacriumDailyBcrBaseline.ps1 rejects the _LCM profile when its folder handling is dirShowAll; the operator's new _LCM session uses dirShowAll and is the one that shows baseline orphans (the old tab with the implicit default hid deleted files on F:). Accept dirShowAll as well.
