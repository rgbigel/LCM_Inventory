# Walkthrough: BUG-348 - Defects Found 2026-11-17 Daemon Gaps Rule Health Tests Tasks

Date: 2026-11-18 15:57:30

## 1. Path taken and issues on the way
- The push dry-run defect was larger than reported: besides the unguarded second maintenance call, the Update-Gemini step and the tool-catalog step also commit during a dry run. All three are now skipped.
- Merged item b is not fixed: `.agents/ACTIVE_SESSION.md` records decision D-31 (held): bundles are not purged at push until their content is absorbed. The 130 remaining pushed bundles are intended.
- Decision for the operator (item 4, third failure): the module allows 10 lifecycle transitions that the authoritative state table (ProposalReviewFlowPolicy) and the test forbid: rejected -> suggested / in_progress, withdrawn -> suggested / in_progress, verified -> completed, in_progress -> in_review / completed, in_review -> verified, held -> superseded, completed -> in_progress. The last one is the `reinstate -Changes` path, which the rule allows, so the test table lacks it. Tightening the others changes engine behaviour; not done without the operator.
- The first rule-health patch left a missing line break (parse error, file briefly unparsable); repaired in the next call and parsed clean.
- Segment 2 is deferred: rebuilding and redeploying the daemon while the operator is away could leave the Control Hub broken.

## 2. Verification evidence (2026-11-18 15:57:30)
- Parse gate: `Invoke-LCM_Push.ps1`, `Test-LCMRuleHealth.ps1`, `ProposalManager.psm1`, `ProposalLifecycle.Tests.ps1` 0 errors.
- `Test-LCMRuleHealth.ps1`: every repository "In Compliance" ("All repositories are in full compliance").
- `ProposalLifecycle.Tests.ps1`: 49 passed, 1 failed (the transition-table decision above).
- Not yet run: a full push dry run (it would need the learned-advice review first); the Maintenance button in the browser.
## 3. Segment 2 status (2026-11-19 17:58:36)

- Item 7 (gofmt): `src/do/main.go` 10.2.1 (trailing blank line); `gofmt -l .` empty, `go vet` clean, `go test` ok, build ok. Formatting only: the deployed `do.exe` needs no redeploy for it.
- Item 8 (hard-coded 10.2.0): done with CRP-361 (status and `-v` report 10.2.8); only the `main.go` file header carried 10.2.0 and is now 10.2.1.
- Merged dirShowAll item: done by BUG-367.
- Items 1, 2, 5, 6: operator decisions (Plan, open items).

## 4. Main Session Continuation (2026-11-19 21:17:37)

| Item | Result |
|:---|:---|
| 2 CORS | `Access-Control-*` wildcard blocks removed from the display, display-page, asset and snapshot handlers (`src/do/daemon.go`); new test `TestNoCORSWildcard`; `gofmt`, `go vet`, `go test` clean; deployed (rollback `scratch/do-before-bug348-cors.exe`); live: `/hub`, an asset and `/displays/status/hub` answer 200 without `Access-Control-Allow-Origin` for a foreign `Origin` |
| 5 Old task | `\LCM_Daemon_InteractiveStarter` deleted (no elevation needed); its definition kept in `scratch/task-LCM_Daemon_InteractiveStarter-before-bug348.xml` |
| 6 Mount proof | read-only probe: Macrium's registry keys hold display settings only, no mount record; `MRMImagePath` / `MRMdrive` are LCM's own telemetry; the mounted volume is no Windows partition (`Get-Partition -DriveLetter F` finds none). Whether Macrium's command-line tools can list mounts is unverified: open |
| 1 Missing routes | waits for CRP-358 (operator decision) |

## 5. Closure (operator 2026-11-20, 2026-11-20 17:18:34)

| Item | Result |
|:---|:---|
| 1 Missing routes | moved to CRP-358 (its owner by the 2026-11-19 decision; cheapest route); BUG-348 no longer carries it |
| 4 Transition table | already aligned by BUG-364: `Test-LcmProposalLifecycleTransition` equals the flat state table; `ProposalLifecycle.Tests.ps1` 50 passed, 0 failed |
| 6 Mount proof | `Test-MountedBaselineCurrency` (new, `modules/LcmMacriumAtoms.psm1`): the mounted image's `cm_activity.log` against the append-only live log (no live entry after the mounted last entry up to the backup completion, 15 min grace); `Invoke-MacriumDailyBcrBaseline.ps1` uses it instead of the registry comparison (`MRMImagePath` / `MRMdrive` stay telemetry). Live probe: G: current (last entry 2026-11-20 00:41:08, 0 missing), F: stale (139 missing). `MacriumBcrReview` + `MacriumBaselineAtoms` tests 19 passed, 0 failed. No BCR relaunch, no remount (operator: BC open on G:) |

Caveat (item 6): an entry written while the backup was running but more than 15 minutes before its completion makes a current image look stale (then the existing log-date fallback still applies).

## 6. Gate 2 (2026-11-20 20:48:28)

- Operator: ACCEPTED, DOIT. The item-6 caveat of section 5 is resolved by the operator's explanation (backup snapshot at start, GoodNight before the backup, BCR copy-over practice), now in `docs/Implementation.md` section 3.4.
