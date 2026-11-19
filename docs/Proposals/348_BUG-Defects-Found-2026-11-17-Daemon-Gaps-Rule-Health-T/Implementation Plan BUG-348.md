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
## Open Items (operator decisions, 2026-11-19)

- Item 1, routes `/set_priority`, `/query_all_short_names`, `/print`, `/abort`: the legacy PowerShell daemon (`tools/LcmDesktopDaemon.ps1`) writes `proposals.json` directly for `/set_priority` and reads `tool_catalog.json` for `/query_all_short_names`; a 1:1 port into the Go daemon would cement the JSON stores that CRP-358 retires and bypass the governed ledger tools. Decide: route them through the governed tools / tables (with CRP-358), or port as they are.
- Item 2, CORS on read-only routes: removing `Access-Control-Allow-Origin: *` can break pages opened outside the daemon origin (file or webview); decide which origins must keep reading.
- Item 5, task `\LCM_Daemon_InteractiveStarter`: action `\` with arguments `...\DoT\do.exe daemon\`, last run 2026-11-14 with result -2147024891 (access denied); the daemon runs from `\LCM_DesktopDaemon_rgbig`. Decide: delete the redundant task or repair it.
- Item 6, BCR post-mount image identity: needs a source that proves which image is mounted (the registry value is written from the requested image); decide the evidence before implementing.
- Live tests still open from segment 1: a full push dry run; the Control Hub Maintenance button.

## Operator Decisions (2026-11-19 19:24:11)

- Item 1 (missing routes `/set_priority`, `/query_all_short_names`): served through the governed tools and the tables, implemented together with CRP-358 (no new JSON dependency).
- Item 2 (CORS): the wildcard goes; only pages served by the daemon itself read the routes (same origin, no header needed); pages opened as a file or in a webview get no live data (operator, after the explanation).
- Item 5 (scheduled task `\LCM_Daemon_InteractiveStarter`): delete it (superseded by `\LCM_DesktopDaemon_rgbig`; operator 2026-11-19 19:29:23).
- Item 6 (BCR mount proof): Macrium keeps no readable mount record (probe 2026-11-19 21:18:57); operator: "the information is in the goodmorning session". Method: content proof as used by `Get-MacriumBaselineState` (`modules/LcmMacriumAtoms.psm1`): the Session Snapshot time read from the mounted drive (`<drive>:/Git_Repositories/LCM_AI/.agents/ACTIVE_CONTEXT.md`, `Saved:`) equals the last GoodNight time, and the volume label matches; the LCM registry values (`MRM*`, `ActM*`) are telemetry only, never proof. To implement: BCR uses this check instead of the registry comparison. Evidence 2026-11-19 21:18:57: SnapshotSavedAt 2026-11-18 23:58:42 = GoodNight, label D4P3-WDB850-D; registry MRM names -09-09, ActM names -10-10 with an implausible time.
