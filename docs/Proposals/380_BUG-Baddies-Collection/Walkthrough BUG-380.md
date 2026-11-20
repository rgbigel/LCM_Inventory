# Walkthrough: BUG-380 - Baddies Collection

Module: docs/Proposals/380_BUG-Baddies-Collection/Walkthrough BUG-380.md  
Purpose: Path taken and test evidence of the released BUG-380 entries.  
Path: LCM_Inventory/docs/Proposals/380_BUG-Baddies-Collection/Walkthrough BUG-380.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Verified  
Date: 2026-11-20 15:58:54

---

## B12 Push Eligibility (released by the operator 2026-11-20: "next is 380 B12")

### Path Taken

- `modules/LCM_PushEligibility.psm1` 10.2.2: new `Get-LCM_PushRepositoryStates` (root and every first-level Git
  repository: remote, upstream, ahead count, branch); `Resolve-LCM_PushPlan` now takes `-AheadRepositories` and
  targets every repository with commits ahead of its remote, governed or not. `origin_repo` / `affected_repos` no
  longer select targets. LCM_Inventory rides along whenever it is ahead (RULE-LCM-005).
- Removed rule: "PUSH requires at least one completed proposal" (a push is maintenance and backup, operator
  2026-11-20). Completed proposals only drive the `completed -> pushed` transition.
- `tools/Invoke-LCM_Push.ps1` 10.2.7: plan from the discovered states; a remote without upstream tracking is
  reported and not pushed; section 4 refreshes the cohort after the pre-push commits (Update-Gemini, catalog,
  ledger projection) instead of adding only LCM_AI.
- Found on the way, not changed (scope): the push still reads `data/proposals/proposals.json` (in sync with
  `proposals.db` on 2026-11-20: same 10 completed items); retirement belongs to CRP-358. The learned-advice gate in
  the push belongs to BUG-383.

### Test Evidence (2026-11-20)

| Check | Result |
|:---|:---|
| `Parser::ParseInput` module, push script, test file | 0 errors each |
| `tests/LCM_PushEligibility.Tests.ps1` (cases rewritten from the operator rule; the old cases encoded the retired rule) | 12 passed, 0 failed |
| `Invoke-LCM_Push.ps1 -DryRun -NonInteractive` | lockstep preflight passed for 15 repositories (root, 9 non-governed, 5 LCM_*); 10 completed proposals would transition to `pushed`; exit 0 |

### Review Item 10 (operator Gate 2 review 2026-11-20, corrected by the operator the same day)

Operator: pushing non-governed repositories can never fail by applying LCM rules (requirement). Correction:
"BootEntryManager and VolumeInventory were put under LCM control, and maybe others, but not all of them. Do not
push if not brought to LCM convergence later."

- `modules/LCM_PushEligibility.psm1`: `Test-LCM_CorePushRepository` (LCM_* repositories, root);
  `Test-LCM_GovernedPushRepository` (core plus inventory `LCMStatus: governed`);
  `Get-LCM_UnconvergedPushRepositories` (governed outside the core whose inventory `CurrentLCMVersion` differs
  from the active LCM version); `Resolve-LCM_PushPlan -HeldRepositories` never targets them and refuses an
  explicit request; the lockstep preflight applies to the core only.
- `tools/Invoke-LCM_Push.ps1`: reports every held repository with its commits that stay local; a non-governed
  repository is pushed as backup (an "LCM Standard Pre-Push Hook" found there is not run); its failed push is
  reported and never blocks the governed cohort or the `pushed` transition.
- The audit (`inventory.json`) runs after the push, so the held set is the one shown in the dry run.

| Check | Result |
|:---|:---|
| `LCM_PushEligibility.Tests.ps1` | 15 passed (classification with inventory; held repositories) |
| `Invoke-LCM_Push.ps1 -DryRun -NonInteractive` | held: AuthorizeMasterUser (3), BackgroundModifier (2), BGMSAMVInv (3), BootEntryManager (3), VolumeInventory (2), all LCM 10.6.3; pushed: root, HaSSD06, HaSSD06_Inventory, LCM_AI, LCM_Inventory, LCM_Shared, LCM_Supervision, LCM_Tools, OneDriveMaintenance, RollingCalendar; 10 proposals to `pushed`; exit 0 |

## B14-B16 Priority Handling (released by the operator 2026-11-20, Q1 A / Q2 A)

### Path Taken

- B14 `modules/ProposalManager.psm1` 10.2.12: `New-LCM_Proposal` gives a BUG priority 6 unless `-Priority` is passed.
- B15 `tools/Invoke-ProposalAction.ps1` 10.2.9: `-Priority` takes the ledger range 0-10; the letters C/H/M/L/D
  remain only as legacy aliases (older items and old command lines); new items and every new call use 0-10
  (operator Gate 2 review 2026-11-20, item 2).
- B16 `modules/ProposalSpecificationState.psm1` 10.2.5: a priority change is mirrored into the YAML `Priority`.
- Ledger (operator Q1 A / Q2 A): BUG-380 -> 7; CRP-385, CRP-386 -> 5 (creation presets no priority); BUG-384 stays 6.
  The three Specification `Priority:` lines were corrected once by hand (they went stale before B16).
- B13 analysed only (evidence in the Specification); its fix rides with CRP-382.

### Test Evidence (2026-11-20 13:54:49)

| Check | Result |
|:---|:---|
| `Parser::ParseInput` of the three changed files and the test file | 0 errors each |
| `ProposalSpecificationState.Tests.ps1` incl. new case "mirrors a priority change without a state change (BUG-380 B16)" | 11 passed |
| `ProposalSpecificationState`, `ProposalSpecificationFence`, `ProposalManager` tests | 35 passed (real ledger untouched: last id 386) |
| CLI `-Action priority -TargetExpression 384 -Priority 6` | accepted (before: refused) |

## B1 Inventory Viewer Documents (released 2026-11-20, Q1 A)

- `tools/Show-LCM_InventoryApp.ps1` 10.2.2: the embedded document list comes from the inventory
  (`RepositoryName` of every entry plus the workspace root) instead of a fixed list (which missed
  RollingCalendar, LCM_Tools, LCM_Supervision, BGMSAMVInv, BootEntryManager and listed LCM_Inventory twice).

| Check | Result |
|:---|:---|
| `Parser::ParseInput` | 0 errors |
| `Show-LCM_InventoryApp.ps1 -NoLaunch` | rendered; documents of RollingCalendar (README, docs/Architecture), LCM_Tools, LCM_Supervision, BootEntryManager, LCM_AI embedded |

## B9 Release Version Alignment 10.8.4 (RULE-REV-007 (4), operator 2026-11-20: "The push will bump the release")

- `LCM_AI/.agents/version.json` 10.7.4 -> 10.8.4 (release +0.1.0, patch kept, D-14).
- README headers of LCM_AI, LCM_Inventory, LCM_Shared, LCM_Supervision, LCM_Tools: DOX header with `Version: 10.8.4`
  (LCM_AI: header was bullet-formatted without a `Version:` line, so the viewer fell back to 10.0.0; LCM_Supervision
  had no header; LCM_Inventory path made git-root-relative). Body text unchanged.
- Viewer rule (`extractDocMeta`, first `Version:` match) reads 10.8.4 in all five READMEs.
- `inventory.json` (`GlobalLCMVersion` 10.6.4) is refreshed by the audit tool at the push, never by hand (RULE-EFF-003).

## B13 Control Hub Shows A State Older Than The Ledger (operator Q-B13 A, 2026-11-20)

### Cause (verified)

- `data/logs/do/do_activity.log` 13:35:50: `Invoke-ProposalAction.ps1 -Action accept -TargetExpression "339"`,
  `Status: DISPATCHED`, `Duration: 0ms` although the hub asks `options: { sync: true }`; hub render log
  `hub-20261120_133551-daemon.log` 13:35:51-55 reads `proposals.json`; the action itself logs at 13:35:52.
- `src/do/daemon.go` `handleExecute`: a body with a top-level `command` parsed as `ExecuteRequest` first, and the
  `options` block was only read in the fallback branch, so the hub `sync` never reached the daemon: the action
  ran asynchronously and the refresh 600 ms later read the ledger before the action had written it.

### Path Taken

- `src/do/daemon.go` 10.2.9: `parseExecuteBody` reads both forms and always applies `options` (`sync`,
  `elevated`, `windowStyle`, `noExit`, `timeoutMs`); new `src/do/execute_body_test.go`.
- `assets/CM_CONTROL_HUB.html` 10.2.11: `executeDaemonCommand` passes `timeoutMs: 590000` (the synchronous
  default of 60 s would now kill long actions such as BCR or COMPLETE; daemon WriteTimeout 600 s).
- `src/do/client.go`: version strings 10.2.9.
- Deployed: rollback `scratch/do-before-bug380-b13.exe`; task `\LCM_DesktopDaemon_rgbig` ended and started.

### Test Evidence (2026-11-20 14:06:01)

| Check | Result |
|:---|:---|
| `gofmt -l`, `go vet ./...`, `go test ./...` | clean / clean / ok (4 new parseExecuteBody cases) |
| `/status` after restart | ONLINE, version 10.2.9, session 1 |
| `/api/action` with the hub body (`options.sync`, 2 s probe command) | `COMPLETED`, exit 0, 2720 ms (before: `DISPATCHED`, 0 ms) |
| Inline scripts of the hub template (`node --check`) | ok (the JSON data block is no script) |
| Hub re-render (`Show-LcmControl.ps1 -NoLaunch`) | template 10.2.11 in the artifact; CRP-339 `in_progress` |

## Operator Live Test And Review (2026-11-20)

- Daemon update (B13): "confirming that the Daemon updates did work" (operator, before the review).
- Gate 2 review D: <-> G:: accepted with changes (items 1-10); corrections recorded in the bundles named there.

## Operator Live Test (2026-11-20 15:58:54)

| # | Step | Result |
|:---|:---|:---|
| 3 | `LCMPush -DryRun` (run by Claude; the operator's first try used a wrong path from the chat) | 5 governed repositories held back, 10 to push, Failed 0: passed |
| 4 | `ProposalAction -Action priority -TargetExpression 387 -Priority 4`, then 5 (run by Claude) | accepted; Specification `Priority: 4`, then `5`: passed |
| 5 | Inventory Explorer -> RollingCalendar -> Docs | README.md and docs/Architecture.md listed: passed (display remarks go to CRP-381) |
| 6 | Inventory Explorer -> LCM_AI -> Docs | README v10.8.4: passed |
| B14 | registering BUG-388 without `-Priority` | priority 6: passed |

## Remaining Entries

B2-B8 and B10 are absorbed into CRP-381, B11 into CRP-382.
