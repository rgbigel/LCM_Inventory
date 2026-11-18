# Walkthrough: CRP-359 - Bundle Document File Names Carry The Item ID

Date: 2026-11-18 22:30:54

## 1. Path taken and issues on the way
- Choice made without the operator: the rule prose keeps the short names (`Specification.md` ...) and RULE-LCM-009 states once that they denote the ID-named documents, instead of rewriting every mention in all rule files.
- The canonical `ProposalReviewFlowPolicy.md` and its adapter got only a new date, no second version step, because the CRP-346 revision already raised them in the same uncommitted cycle (one increment per commit cycle).
- Found while patching "Show CRP": the CRP-354 patch had written 35 lines of the Control Hub with doubled line endings (CR CR LF), and the BUG-352 help patch 25 lines of `lcm-tool-explorer.js`; both repaired (the CRP-354 part is already committed, the repair rides with this change).
- Migration: 18 open items (including CRP-253 held and the completed, unpushed items), 54 files renamed; ledger parity verified afterwards (333 proposals).

## 2. Verification evidence (2026-11-18 16:11:42)
- Parse gate: all changed PowerShell files 0 errors; `node --check` Control Hub main script and Tool Explorer OK.
- Tests: `ProposalScaffold` 5/5, `ProposalManager` 21/21, `ProposalCompletion` 7/7, `ProposalSpecificationFence` 4/4, `Fix-Documentation` and `LCM_PushEligibility` passed; `ProposalSpecificationState` 8/9 - the failing case ("mirrors cross-repository bundles using their owner") fails the same way with the committed HEAD modules (pre-existing).
- Ledger: `Sync-LcmProposalsDb.ps1 -Action Verify` PASS after the migration; live `last_proposal_id` unchanged by the test runs.
- Operator check at Gate 2: "Show CRP" on an open item shows tabs `Specification <ID>.md`, `Implementation Plan <ID>.md`, `Walkthrough <ID>.md` (refresh the Control Hub page first).

## 3. Revision 2 (2026-11-18 21:05:57)

- `docs/Requirements.md` 10.2.2 -> 10.2.3: REQ-WINV-014 gets three bullets (open items, live tests, design material).
- Check: Markdown structure unchanged (heading levels, list indentation); UTF-8 without BOM.

## 4. Revision 3: folder names <nnn>_<Kind>-<Slug> (2026-11-18 22:30:54)

- Migration (one-time scratch script): 174 folders renamed (incl. 21 without ledger row: v7/v8 bundles CRP-162..188 and test residue CRP-243..246); 157 references in 81 files corrected (bundle headers, `.agents/ACTIVE_CONTEXT.md`, `.claude/translation` WORKPLAN / NOTE-LineEndings); 440 ledger string fields corrected. Logs, review receipts, analysis runs and `LCM_AI/docs/Logs` left as historical evidence.
- Issue on the way: the first run collected file paths before renaming the folders and stopped at the first file (no content or ledger change); resumed with current paths.
- Code: `ProposalManager.psm1` 10.2.9 (new folder name; an old-form folder of the same ID is still reused), `Invoke-LcmMajorCleanup.ps1` (test-residue pattern both forms), Control Hub 10.2.10 (`displayItemId`). Rules: RULE-LCM-009 / -011 canonical 10.3.4 + adapter, hash `4B86EA2345F55B19`; REQ-WINV-014.
- Minimal tests (operator).

| Check                                          | Result                                         |
|:-----------------------------------------------|:-----------------------------------------------|
| Folders old form / new form                    | 0 / 174                                        |
| References to old folder names left            | 0                                              |
| Ledger parity; `bundle_dir` resolvable          | PASS (336); 153 of 173 (as before)             |
| Parse gate; `node --check` hub                 | 0 errors; OK                                   |
| Scaffold, ProposalManager, Cleanup, ControlHub tests | 37 passed, 5 failed (the 5 pre-existing ControlHubSafety cases) |
| Control Hub screenshot                         | IDs shown as 362_CRP, 360_BUG, ...             |