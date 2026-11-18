# Specification: CRP-355

Module: docs/Proposals/355_CRP-Major-Version-Cleanup-With-In-Place-Log-And-Propos/Specification CRP-355.md  
Purpose: Major Version Cleanup With In-Place Log And Proposal Ledger  
Path: LCM_Inventory/docs/Proposals/355_CRP-Major-Version-Cleanup-With-In-Place-Log-And-Propos/Specification CRP-355.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 22:10:04

```yaml
CRP-ID: CRP-355
Title: Major Version Cleanup With In-Place Log And Proposal Ledger
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 22:10:04
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-18: a manually triggered cleanup with a new design, because earlier partial cleanups left dead code. After two changes of the major version (current M, delete items of M-2 and older), old items are deleted completely in logs and Proposals; what remains is an in-place log and a proposal ledger, the latter listing the completed proposals. Proposals that are held or otherwise unfinished business are kept regardless of their major version. The cleanup is triggered manually. Include suggestions for further deletions at cleanup.
- Specification accepted by operator instruction 2026-11-18 ("crp 346 and 355", full review on return).
- Review: this Specification (new section 4: rule-text drafts) and the Walkthrough (three deviations from the Gate 0 text, one known gap). Design option A (operator 2026-11-18): two phases, prerequisites first.

## 2. Gate 0 Contract (option A, operator 2026-11-18)

### Target State
Phase 1 - prerequisites:
- T1 Release register: a recorded list of major releases (major, first commit, date) seeded from the commit history (7.0.0 2026-08-29, 8.0.0 2026-09-26, 10.0.0 2026-10-13; no 9.x), so "M-2 and older" can be computed. Home: a section of `LCM_AI/docs/Logs/03_Propagation-and-Continuous-History/Major_Version_Milestone_Rollup.md` and a `releases` table in `proposals.db`.
- T2 Origin major per proposal: each ledger row carries its origin major (from `lcm_version` "Legacy (<10.0)" and the release register; re-stamped rows corrected where evidence exists, else marked `unknown`).
- T3 Reconciliation: one read-only report comparing `proposals.json` and `proposals.db` (keys, states, cohorts, obligations, settings) before any deletion; differences resolved by the operator (aligned with CRP-358).

Phase 2 - the cleanup:
- T4 One manually triggered tool (`Invoke-LcmMajorCleanup.ps1`): `-Report` writes a dry-run manifest (JSON + Markdown) to `LCM_Inventory/data/analysis/history/` listing every file, folder and ledger row to delete, with counts and bytes; `-Apply -Manifest <file>` deletes exactly the manifest entries after the operator confirmed it, then stops at Gate 2.
- T5 Selection: proposals in a final state (pushed, superseded, rejected, withdrawn) with origin major <= M-2, their bundle folders and flat files, their review receipts (`data/reviews`), and logs whose period ends before the M-1 release date.
- T6 Protection: never deleted, whatever the major: held, suggested, in_progress, verified, in_review, completed (unpushed) items; members of an open cohort; items cited in `.agents/ACTIVE_CONTEXT.md` or `LEARNED_ADVICE.md`; permanent evolution history (`LCM_AI/docs/Logs`, RULE-DOC-006).
- T7 Completed-proposal ledger: deleted proposals keep a compact row in `proposals.db` (ID, kind, title, final state, origin major, version, created / completed / pushed dates, commit SHA or `unknown`, GitHub URL, bundle path, archived_at); the row is never deleted, so the ID counter stays continuous. A committed Markdown projection lists these rows.
- T8 In-place log: each run appends one block to `Major_Version_Milestone_Rollup.md`: run ID, time, M, cutoff date, per store the deleted period, counts and bytes, the repository SHAs before deletion (retrieval anchor, `git show <sha>:<path>`), the kept protected items, and which deleted evidence was untracked and is therefore not recoverable.
- T9 Further deletions: the report also lists the cleanup candidates of section 3, each to be confirmed per run.

### Invariants and Exit Criteria
- No deletion without a confirmed manifest; the apply step deletes nothing that is not in the manifest (count and hash check).
- No dry-run mode passes control to an unguarded second call (lesson from the push maintenance defect).
- Exit: a report run on the live workspace lists the selection and the protected items; an apply run on a test copy deletes exactly the manifest, writes the in-place log block and the compact ledger rows; tests for selection, protection and manifest check.
- Rule texts: RULE-DOC-006 (permanent history excluded, `Deletions/` reference updated), RULE-DOC-008 (exemption for absorbed bundles of pushed items, or per-run approval), RULE-ANA-009 (definition of "referenced"), RULE-LCM-020 (retrieval via git for tracked files) - drafted in the bundle, applied under ADMINMODE with RULE-AUTH-002 sync.

### Explicit Non-Goals
- The defects found by the analysis are BUGs, not this CRP: the unguarded second maintenance call in `Invoke-LCM_Push.ps1` (cause of the 186 deleted logs), the missing bundle purge at push (RULE-LCM-020), the dead Control Hub Maintenance button.
- Retiring the JSON stores (CRP-358); this CRP only needs the reconciliation report.
- Automatic or scheduled cleanup.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Further Deletion Candidates (analysis 2026-11-18, to be confirmed per run)
- Direct: `Invoke-PrivilegedTool.ps1` + `PrivilegedTool.cmd`; `RunShell.cmd` / `RunShell.ps1` (unreferenced); dangling launchers `DismountMacriumBaseline.cmd`, `SystemPrivilegeXY.cmd`; duplicate launchers (`ArchiveClean.cmd` / `archive-Clean.cmd`, `LCM_Maintenance.cmd`) and duplicate intents; `proposals.json.bak`, `data/proposals/CRP-20260825-*.json`; test bundles CRP-243..246; old `.copilot/History/Logs`; regenerable `data/artifacts` HTML and old rollback copies in `scratch/`.
- After moving callers to `do.exe`: `Invoke-InteractiveDesktop.ps1` (14 referencing files), `Invoke-LcmAction.ps1` with `run.cmd` / `LcmAction.cmd`, `lcmdo.cmd` / `InvokeLcmDo.cmd`, the legacy `-ElevatedWorker` path.
- Consolidation: four overlapping daemon-log purgers into one atom.
## 3a. Operator Decisions 2026-11-18 (Q1-Q3)

- The one-time part (everything of major 8 and older, incl. ids below 150) was applied on 2026-11-18 as test (operator: "let it rip"); the regular run follows at the move to the next release.
- Q1: review receipts that git does not track are deleted like the others ("anything before version 8.x.x is generally dead meat").
- Q2: the further candidates get no special treatment; the regular run at the bump to 11 handles them.
- Q3: ids below 150 count as major 8 (one-time rule, removed after the first apply run): the 10.0.0 migration overwrote their version and dates (all 2026-10-13 at round times), so their real age cannot be read. Open items stay protected.
## 4. Rule Texts To Apply (draft, ADMINMODE)

- RULE-DOC-006 (DocumentationStandardsPolicy): replace "At major release M flush transient logs, scratch and `Deletions/` older than M-2" by: "A manually triggered cleanup (`Invoke-LcmMajorCleanup.ps1`, report -> operator confirmation -> apply) deletes proposals in a final state of major M-2 and older with their bundles and flat files, review receipts and logs dated before the first release above M-2; unfinished, held, open-cohort and cited items are kept; each run appends a block to the in-place log in `Major_Version_Milestone_Rollup.md` and compacts the deleted proposals to rows of the completed-proposal ledger." Keep "never prune permanent evolution history".
- RULE-DOC-008: add "Bundles and flat specifications of proposals deleted by a confirmed cleanup manifest are exempt; the manifest is the operator approval."
- RULE-ANA-009: define "referenced": cited by an unfinished proposal, an open cohort, or the continuity files.
- RULE-LCM-020: add "Bundles deleted by the cleanup stay retrievable through `git show <sha>:<path>` with the SHAs recorded in the in-place log."
## Absorbed Operator Remarks

> we really need to do a cleanup; some of this had been done a long time ago, so it has left dead code. We need a new design.
> What i want cleaned: after two changes to the major version, i want old items to be completely deleted in logs, Proposals, and an in-place log and proposal ledger (the latter listing the completed Proposals). Proposals that are in HELD or "unfinished business" are to be kept regardless of major version number.
> The cleanup will be triggered manually.
> Start a CRP for this, and make suggestions for further deletions at cleanup

(Operator, 2026-11-18. Gate 0 contract to follow from the read-only inventory and design analysis started the same day.)

> you did not do the temporary deletes now? that would be a good test to use.

> but the code for the temp deletes is not meant as being permanent in the tool. And, since we are at V 10, it would not touch anything older than 8.x.x anyway. So in my mind we can "let it rip".

(Operator, 2026-11-18.)
