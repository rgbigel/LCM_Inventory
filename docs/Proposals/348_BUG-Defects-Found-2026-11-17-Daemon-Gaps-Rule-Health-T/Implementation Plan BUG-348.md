# Implementation Plan: BUG-348 - Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks

Date: 2026-11-18 15:57:30

## Segment 1 changes
- `tools/Invoke-LCM_Push.ps1` (10.2.4 -> 10.2.5): with `-DryRun`, steps 1 (Update-Gemini + LCM_AI commit), 2 (tool catalog + root commit) and 3 (full maintenance) are skipped with one notice.
- `assets/CM_CONTROL_HUB.html` (template 10.2.5 -> 10.2.6): `runWorkspaceMaintenance` calls `tools/Invoke-LCM_Maintenance.ps1`.
- `tools/Test-LCMRuleHealth.ps1` (10.2.0 -> 10.2.1): `.agents` junction to `LCM_AI\.agents` counts as a valid link.
- `modules/ProposalManager.psm1` (10.2.6 -> 10.2.7): legacy progress for `held` is `blocked`.
- `tests/ProposalLifecycle.Tests.ps1`: the BCR-evidence case stubs `Update-LcmControlHubAfterCompletion`.

## Segment 2 (pending, Go daemon)
- Routes `/set_priority`, `/query_all_short_names`, `/print`, `/abort`; CORS for read-only routes; scheduled task action path; post-mount image identity check; gofmt; version string; rebuild and redeploy of `do.exe`.