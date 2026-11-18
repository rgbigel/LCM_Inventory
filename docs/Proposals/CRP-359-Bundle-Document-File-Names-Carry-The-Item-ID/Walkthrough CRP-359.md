# Walkthrough: CRP-359 - Bundle Document File Names Carry The Item ID

Date: 2026-11-18 21:05:57

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
