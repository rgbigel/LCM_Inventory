# Walkthrough: CRP-355 - Major Version Cleanup With In-Place Log And Proposal Ledger

Date: 2026-11-18 23:30:27

## 1. Path taken and issues on the way
- Deviation (T1): the release register is the Markdown table in the rollup only; the `releases` table in `proposals.db` was not added, to avoid a schema change ahead of CRP-358.
- Deviation (T2): the origin major is derived at report time from `lcm_version` and not stored in the ledger. Known gap: ids >= 100 re-stamped as 10.0.0 at the migration although older (e.g. BUG-111 with a v7.3.0 flat file) are not selected; correcting them needs per-item evidence (open point for the operator).
- Deviation (T3): the reconciliation is the existing parity check (`Sync-LcmProposalsDb.ps1 -Action Verify`) embedded in the report, not a separate field-by-field report.
- The further candidates are only those with exact paths from the analysis; callers of `Invoke-InteractiveDesktop.ps1`, `lcmdo` and `run.cmd` still need moving to `do.exe` before those can be candidates.
- Rule texts drafted in Specification section 4, not applied (ADMINMODE).
- No apply run on the live workspace: it waits for the operator's confirmation of the manifest hash.

## 2. Verification evidence (2026-11-18 16:16:16)
- Parse gate: tool and test 0 errors.
- `Invoke-Pester tests/LcmMajorCleanup.Tests.ps1`: 4/4 (selection by major and date; held, newer and cited items kept; wrong hash refused with nothing deleted; apply deletes exactly the manifest, compacts the row with `pushed_at`, writes ledger and log block). Live ledger untouched.
- Live report `CLEANUP-20261118_161519` (`LCM_Inventory/data/analysis/history`): 239 selected entries (24 flat proposal files, 215 review receipts, 2.84 MB; 155 receipts untracked = not recoverable), 99 ledger rows (ids 1-99, "Legacy (<10.0)"), 0 protected kept, 12 candidates listed (not selected), reconciliation PASS (333 proposals). Hash `94df374e185de3196631e5ecabe04963dbc0e665adb346a606ad675025a9cb32`.
- To apply after review: `Invoke-LcmMajorCleanup.ps1 -Apply -Manifest <json> -ManifestHash <hash>`, then Gate 2.

## 3. Revision: one-time rule for re-stamped ids (2026-11-18 22:03:57)

- Data check: ids 100-149 (50 items: 49 pushed, 1 rejected) all carry `lcm_version` 10.0.0 and a first state-history entry on 2026-10-13 at round times (17:30, 18:00, ...): the original dates were overwritten; per operator Q3 the one-time rule applies.
- `tools/Invoke-LcmMajorCleanup.ps1` 10.7.4 -> 10.7.5: `Get-CleanupOriginMajor` returns 8 for ids < 150 (marked TEMPORARY).
- Test fixture: item 120 (10.0.0) selected, item 150 (10.0.0) kept; the "newer" fixture item renumbered 3 -> 203.

| Check                                   | Result                                                   |
|:----------------------------------------|:---------------------------------------------------------|
| Parse gate (tool, test)                 | 0 errors                                                 |
| `LcmMajorCleanup.Tests.ps1`             | 4/4                                                      |
| Live report `CLEANUP-20261118_220338`   | 72 flat files, 215 receipts, 149 ledger rows (ids 1-149) |
| Reconciliation                          | PASS (336 proposals)                                     |
| Apply                                   | not run (next release)                                   |

## 4. One-time apply and removal of the temporary rule (2026-11-18 22:10:04)

- Apply of `CLEANUP-20261118_220338` (hash confirmed by the operator): 287 entries deleted (72 flat proposal files, 215 review receipts, 155 of them untracked), 149 ledger rows compacted, `docs/Proposals/LEDGER_COMPLETED.md` written, in-place log block appended to `Major_Version_Milestone_Rollup.md`.
- The temporary rule (ids < 150 = major 8) and its fixture cases removed again; the tool header records the one use.
- Found on the way: a report with nothing to select failed (`Measure-Object` has no `Sum` for an empty list under StrictMode); sums now through `Get-CleanupSum`; new test case.

| Check                                     | Result                                           |
|:------------------------------------------|:-------------------------------------------------|
| Ledger after apply                        | 336 proposals, parity PASS, counter 362 unchanged |
| Open items                                | all 10 intact                                    |
| Flat files with id < 150 left             | 0                                                |
| Review receipts left                      | 174                                              |
| `LcmMajorCleanup.Tests.ps1`               | 5/5                                              |
| Live report after the apply               | 0 selected, 0 ledger rows                        |

## 5. Revision: compacted rows keep the common fields (2026-11-18 23:22:39)

- Found by the CRP-357 regression run: the 149 compacted rows lacked `origin_repo`, `bundle_id`, `author`, `progress_state`, `priority`; `ProposalManager.psm1` reads `origin_repo` on every row and failed under StrictMode (cohort and repository resolution).
- Ledger: the five fields restored from the last committed `proposals.json` (745 values, 16 neutral defaults where HEAD had none); `details` kept as an empty field.
- Tool: compaction keeps these fields and empties `details`; test asserts `origin_repo` on a compacted row.

| Check                                   | Result                                   |
|:----------------------------------------|:-----------------------------------------|
| Ledger parity after restore             | PASS (336)                               |
| `LcmMajorCleanup.Tests.ps1`             | 5/5                                      |
| `ProposalLifecycle.Tests.ps1`           | COH routing case passes again; 1 failure = pre-existing transition-table case (BUG-348) |

## 6. Revision A/B/C: no field is ever removed (2026-11-18 23:30:27)

- A: the 149 archived rows restored in full from the last committed `proposals.json`; markers (`origin_major`, `completed_at`, `pushed_at`, `archived_at`, `archive_run`) kept on the full row. Comparison with HEAD: 0 fields missing or differing.
- B: the cleanup tool archives by adding markers only; the completed-proposal list reads fields guarded (a full row may lack one).
- C: `Set-ProposalStore` refuses a write in which an existing row would lose a field (only the transient `status_note` may go); `ProposalManager.psm1` 10.2.10.
- How the defect arose (operator question): my first design whitelisted 10 fields per archived row; `Set-ProposalStore` accepted any row shape; the parity check compares values, not completeness; my test only checked that `details` disappeared.

| Check                                           | Result                                    |
|:------------------------------------------------|:------------------------------------------|
| Restore vs HEAD (149 rows, every HEAD field)    | 0 missing, 0 differing                    |
| Ledger parity                                   | PASS (336)                                |
| `ProposalStoreFieldGuard.Tests.ps1` (new)       | 2/2                                       |
| `LcmMajorCleanup.Tests.ps1`                     | 5/5 (asserts details and history kept)    |
| Lifecycle, Manager, Completion, Scaffold tests  | pass; 1 failure = pre-existing transition-table case (BUG-348) |