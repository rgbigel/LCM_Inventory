# Walkthrough: CRP-355 - Major Version Cleanup With In-Place Log And Proposal Ledger

Date: 2026-11-18 16:16:16

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