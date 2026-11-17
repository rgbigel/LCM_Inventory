# Walkthrough: BUG-341 - Cohort BCR Launches Per Member With Stale Remount

## 1. Executive Summary
Implementation and verification records for BUG-341.

Implemented 2026-11-17 by Claude in DOIT (operator: "start with BUG-341"). Components C1-C3 per Implementation_Plan.md.

## 2. Verification Evidence
- Pending implementation execution.
- 2026-11-17 12:00 Root-cause evidence: `LCM_Inventory/logs/Invoke-MacriumDailyBcrBaseline-20261116_214346.log` ff.: "Mounted baseline at F: (2026-11-14 17:40:55) is stale" logged again at 21:45:04, right after the 07-07 image had been mounted at 21:44:02 and the registry set to `MRMImagePath = ...-07-07.mrimgx` (21:45:03). Each detach succeeded (no F: lock evidence).
- Parse gate (`Parser::ParseFile`): 0 errors in `Invoke-ProposalAction.ps1`, `Invoke-MacriumDailyBcrBaseline.ps1`, `MacriumBcrReview.Tests.ps1`; CRLF, UTF-8 without BOM; added lines ASCII only; no comment line removed (11 removed lines = 9 header fields, 1 condition line, 1 call line).
- `Invoke-Pester tests/MacriumBcrReview.Tests.ps1`: Passed=14 Failed=0 (incl. the 2 new BUG-341 tests).
- `Invoke-Pester tests/ProposalLifecycle.Tests.ps1`: Passed=47 Failed=3; live `proposals.db` / `proposals.json` hashes unchanged. The 3 failures are in `ProposalManager.psm1` tests BUG-341 does not touch (transition table `held`, missing `logs/history/cm_activity_v5_v6_history.log`, hold state `blocked` vs `held`): pre-existing drift, to be registered separately.
- Registry at test time: `MRMImagePath = B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-07-07.mrimgx`, `MRMdrive = F:`; F: not mounted (after shutdown). Today's completed image: `B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-08-08.mrimgx` (2026-11-17 09:10:44).
- Live test 2026-11-17 12:06-12:07 (`bcr COH-331`, 7 members): one mount of `B:\Backups\D4P3+4-WDB850-AD\0BFC8B1DF80AFC5F-@B_D4P3+4-WDB850-AD-08-08.mrimgx` at F:, one Beyond Compare window (12:06:16); members 2..7 logged "is today's completed image ... (registry identity)" and "via fast-path; did not launch a review window"; all members `in_review`. Operator accepted BUG-341 at Gate 2 (2026-11-17).
