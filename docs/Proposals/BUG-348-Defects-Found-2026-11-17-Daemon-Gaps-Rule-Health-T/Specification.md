# Specification: BUG-348

Module: docs/Proposals/BUG-348-Defects-Found-2026-11-17-Daemon-Gaps-Rule-Health-T/Specification.md  
Purpose: Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks  
Path: LCM_Inventory/docs/Proposals/BUG-348-Defects-Found-2026-11-17-Daemon-Gaps-Rule-Health-T/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-17 14:27:40

```yaml
CRP-ID: BUG-348
Title: Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 14:27:40
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Collected defects found 2026-11-17 (operator: own BUG, preferably one): (1) Go daemon port gaps: pages call /set_priority, /query_all_short_names, /print, /abort, which src/do does not register (fall to "/", POST -> 405). (2) Read-only display routes send Access-Control-Allow-Origin * (foreign pages can read displays, proposals, logs). (3) Test-LCMRuleHealth.ps1 reports Static Rule Copies for every child repo: it checks <repo>\.agents\rules, the junction is <repo>\.agents since BUG-338 (false positive). (4) ProposalLifecycle.Tests.ps1: 3 failures (transition table held, missing logs/history/cm_activity_v5_v6_history.log, hold state blocked vs held). (5) Scheduled task \LCM_Daemon_InteractiveStarter has a malformed action path (\ ...do.exe daemon\). (6) BCR post-mount check does not verify the mounted image identity (only volume label + Git_Repositories folder); registry MRMImagePath is written from the requested image. (7) gofmt deviations in src/do client.go, main.go, types.go, winutil.go. (8) do.exe status/version report a hard-coded 10.2.0.

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.
