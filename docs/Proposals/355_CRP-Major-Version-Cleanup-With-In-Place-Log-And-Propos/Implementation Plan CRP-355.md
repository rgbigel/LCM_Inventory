# Implementation Plan: CRP-355 - Major Version Cleanup With In-Place Log And Proposal Ledger

Date: 2026-11-18 16:16:16

## Changes per file
- `LCM_AI/docs/Logs/03_Propagation-and-Continuous-History/Major_Version_Milestone_Rollup.md` (6.0.0 -> 10.7.4): section 2 Release Register (majors 4-10, dates from tags and commit messages, 9 never released), section 3 Cleanup Runs (in-place log).
- `LCM_Inventory/tools/Invoke-LcmMajorCleanup.ps1` (new): `-Report` (manifest JSON + Markdown in `data/analysis/history`, hash), `-Apply -Manifest -ManifestHash` (hash check, deletion of the selected entries, links removed as links, ledger compaction, `docs/Proposals/LEDGER_COMPLETED.md`, in-place log block with repository SHAs).
- `LCM_Inventory/tests/LcmMajorCleanup.Tests.ps1` (new, 4 tests, isolated workspace and store).
- Catalog: tool registered (`invoke-lcmmajorcleanup`, not elevated).

## Selection rules
- Proposals: state pushed / superseded / rejected / withdrawn and origin major <= M-2 (from `lcm_version`); their `bundle_dir` and flat files `docs/Proposals/<ID>-*`.
- Review receipts `data/reviews/*_<yyyyMMdd>_*` and logs in `logs/`, `data/logs/` (except `cm_activity.log`) dated before the first release above M-2.
- Protected: unfinished states, open cohorts, IDs cited in `.agents/ACTIVE_CONTEXT.md` / `LEARNED_ADVICE.md`; `LCM_AI/docs/Logs` is never scanned.
- Further candidates (CRP-355 section 3) are listed; selected only with `-IncludeCandidates`.