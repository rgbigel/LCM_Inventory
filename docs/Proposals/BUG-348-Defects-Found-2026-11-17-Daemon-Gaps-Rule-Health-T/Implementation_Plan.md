# Implementation Plan: BUG-348 - Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks

## 1. Executive Summary & Problem Context
Collected defects found 2026-11-17 (operator: own BUG, preferably one): (1) Go daemon port gaps: pages call /set_priority, /query_all_short_names, /print, /abort, which src/do does not register (fall to "/", POST -> 405). (2) Read-only display routes send Access-Control-Allow-Origin * (foreign pages can read displays, proposals, logs). (3) Test-LCMRuleHealth.ps1 reports Static Rule Copies for every child repo: it checks <repo>\.agents\rules, the junction is <repo>\.agents since BUG-338 (false positive). (4) ProposalLifecycle.Tests.ps1: 3 failures (transition table held, missing logs/history/cm_activity_v5_v6_history.log, hold state blocked vs held). (5) Scheduled task \LCM_Daemon_InteractiveStarter has a malformed action path (\ ...do.exe daemon\). (6) BCR post-mount check does not verify the mounted image identity (only volume label + Git_Repositories folder); registry MRMImagePath is written from the requested image. (7) gofmt deviations in src/do client.go, main.go, types.go, winutil.go. (8) do.exe status/version report a hard-coded 10.2.0.

## 2. Gate 0 Traceability
- Map each implementation component and verification activity to the accepted Gate 0 target-state clause.

## 3. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks.

## 4. Verification Plan
- Automated Pester tests and readiness quality gates.
