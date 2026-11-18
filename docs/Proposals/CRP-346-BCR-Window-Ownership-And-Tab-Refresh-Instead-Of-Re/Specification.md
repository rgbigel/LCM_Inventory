# Specification: CRP-346

Module: docs/Proposals/CRP-346-BCR-Window-Ownership-And-Tab-Refresh-Instead-Of-Re/Specification.md  
Purpose: BCR Window Ownership And Tab Refresh Instead Of Relaunch  
Path: LCM_Inventory/docs/Proposals/CRP-346-BCR-Window-Ownership-And-Tab-Refresh-Instead-Of-Re/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-18 13:33:58

```yaml
CRP-ID: CRP-346
Title: BCR Window Ownership And Tab Refresh Instead Of Relaunch
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-18 13:33:58
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-17: BCR recognises the BC window it started, locates the _LCM tab (AHK atom) and refreshes it instead of opening another window. Depends on the non-elevated BC and AHK atom CRPs.
- Since 2026-11-18 it also carries the rule clarifications for review completion and implied cohorts (section 4, R1-R5).
- Review: this Specification only. The Implementation Plan and Walkthrough are not written yet (implementation has not started).

## 2. Gate 0 Contract
### Target State
- BCR records the BC window it starts (process ID, window handle, start time, review identity) and later recognises it by that record, not by window title.
- When such a window is open and the baseline is mounted, BCR does not launch another window: it locates the `_LCM` tab (tab names through the CRP-345 tab atom), activates it and performs a Full Refresh.
- Context (2026-11-17 probe): window titles show only the active tab; UI Automation and MSAA expose the tab strip but no tab names; each tab is one `TDirCompareView` child window (count and active tab readable).

### Invariants and Exit Criteria
- Operator windows and tabs that BCR did not start are never closed or retitled (RULE-REV-012); existing tabs are preserved.
- A remount (newer image) still triggers a refresh of the recorded window, not a relaunch (confirmed by the operator after the 2026-11-18 test: "a refresh would be perfectly sufficient").
- A window counts as the same review when its compare roots are `F:\Git_Repositories` and `D:\Git_Repositories`; the folder currently focused below the roots (shown in the path bar and tab) is irrelevant (operator 2026-11-18).
- Exit: two consecutive BCR runs on a mounted baseline leave exactly one BC window; the second run refreshes the `_LCM` tab; works with another tab active.

### Explicit Non-Goals
- Post-mount image identity verification (convergence/BCR follow-up, 2026-11-17 question).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## 4. Amendment 2026-11-18: Review Completion and Implied Cohorts (operator option C)

Source: meta analysis of the stalled CRP-350 completion (2026-11-18). Tool defects go to BUG-351; this section carries only the rule clarifications.

### 4.1 Target State
- R1 (completion precondition): `COMPLETE` accepts `in_review` and also `completed` for an item whose affected repositories are not all committed yet; `completed` confirms the completion and is not a boundary for the remaining repository commits.
- R2 (implied cohort membership): when a review scope is implied (bare `bcr`, or a named item with related items), the resulting temporary cohort contains only items whose state allows review acceptance (`verified`, `in_review`); their cross-repository review obligations are registered before the item completes (BUG-351 registers them at completion from the live changes, so that no extra BC window per repository opens).
- R3 (items not ready): an item in `in_progress` (DOIT or standard) whose changes lie inside the reviewed area is not a cohort member; the operator is asked: (a) `do <ID>` (finish to `verified`, then include), (b) exclude it so its changes ride as WIP (precedent: CRP-343, decision A, 2026-11-17), (c) `hold`. Before asking, check whether the item's intent blocks the target at all.
- R4 (DOIT): DOIT ends at Gate 2 in `verified`; a DOIT item joins an implied cohort only once it is `verified`.
- R5 (bare `bcr`): bare `bcr` is the primary form; the item parameter is legacy and only labels the window title (operator 2026-11-17).
- R6 (RULE-REV-012): a newer image is remounted, but the recorded review window is refreshed, not relaunched; today the rule text ("never relaunch BC or remount unless the image changed") permits a relaunch on an image change.

### 4.2 Invariants and Exit Criteria
- Rule texts affected: RULE-LCM-002 (scope fallback, cohort membership), RULE-LCM-016 (`COMPLETE`), RULE-REV-001 (disposition per repository from one workspace review), macro entries `BCR` and `COMPLETE`; changed under ADMINMODE with RULE-AUTH-002 sync.
- Exit: a multi-repository item reviewed once in BCR completes with one `COMPLETE` (all affected repositories committed, item `completed`); an `in_progress` related item produces the R3 question, not a failure.

### 4.3 Explicit Non-Goals
- Tool fixes (obligation registration, proposal creation/merge, Tool Explorer): BUG-351.
- Ledger store consolidation (proposals.db sole store, decision B) and path-to-item attribution.
## Evidence: BCR test 2026-11-18 13:23 (BUG-340)
- BCR remounted F: from the 2026-11-14 image to today's image (10:35) and launched a new BC window (pid 40376, 13:23:55) although the review window of 2026-11-17 (pid 33268, 20:09:02) was open. The tool then exited with code 1 (cause unknown, see BUG-340 report).
- The review tag was set on the wrong window: the old window's title now ends in `[BUG-340]`, the new window has no tag (title set by window search, not by the recorded process).
- Both windows show the same compare roots; the old one is focused on `LCM_AI\.claude\rules\process`, the new one on the root (operator observation; window captures taken read-only by `PrintWindow`).
- How the old window picked up the new baseline is unknown; BC's automatic folder refresh after the remount is a guess, not verified.
## Absorbed Operator Remarks

- 2026-11-17 15:51:38 (operator, CRP-350 Gate 2): "the bcr opened again instead of refresh" - Gate 2 of CRP-350 postponed. Evidence: `Invoke-ProposalAction.ps1 -Action bcr 350` at 15:48:25 reused the mounted F: baseline (no remount) but logged "Dispatched Beyond Compare 5 to Session 1 via Desktop Daemon" and reported `Launched: False`, `ReusedExistingReviewWindow: False`; a new BC window opened although one was already open. Receipt: `LCM_Inventory/scratch/BC_Review/BCR-Cohort-5392076e20dd/BCR-Cohort-5392076e20dd.json`.

Shared operator remark of 2026-11-17, quoted verbatim in CRP-343 `Specification.md`.

> 2.2 precondition in_review for completion is imprecise, completed items are not a boundary, just confirms completion
> 2.4 center of attention: when a (automatic, hence: temporary) cohort is implied/created, the rules must be made clear that this can only accept items in states that accepts review acceptance. This in turn requires that Register-LcmCrossRepositoryReviewObligation must have been used. an "implied" cohort that contains items with CRP's "in_progress" makes no sense as part of DO. Unclear: what should be the rule for DOIT?
> I2: [...] the inter-relation of CRP-350 and CRP-343 that you correctly identified, should mean that either the status of 343 (in progress, insufficient) would be put up as a question to the user (possible answer: "do 343", leading to an acceptable state). Alternatively, you could have checked if the intent of 343 was blocking the completion of 350 at all!

(Operator, 2026-11-18, comments on the CRP-350 meta analysis; then option C: rule changes as amendment to CRP-346; source of section 4.)

> the result of the test are different from expectation: even after reassigning a new drive F:, a refresh would per perfectly sufficient! (but good that you remembered to get today's baselenie,)
> please check the two open windows, they really show the same comparison. Only, the older one (which has auto-refeshed? I have no idea how BC found out about the new baseline) is showing the currently focussed directory in the tabs, and the new one has only the root focussed. The part following the F: or D:\Git_Repositories is irrelevant when checking for the baseline compare.

(Operator, 2026-11-18, after the BUG-340 BCR test; source of the root-pair identity, R6 and the evidence section.)
