# Specification: BUG-380

Module: docs/Proposals/380_BUG-Baddies-Collection/Specification BUG-380.md  
Purpose: Baddies Collection  
Path: LCM_Inventory/docs/Proposals/380_BUG-Baddies-Collection/Specification BUG-380.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Review  
Date: 2026-11-20 14:06:01

```yaml
CRP-ID: BUG-380
Title: Baddies Collection
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 14:06:01
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 7
App-ID: None
```

---

## 1. Executive Summary & Intent

A collection point for defects ("baddies") the operator finds in live tests. Each entry names what the operator saw
and the requirement it violates. The operator releases the list for fixing (DOIT) when he decides; until then
nothing here is changed.

## 2. Baddies

| # | Found | What the operator saw | Cause (verified) | Requirement |
|:---|:---|:---|:---|:---|
| B1 | Inventory Viewer, "Docs" of RollingCalendar (live test 2026-11-20) | empty document table although the repository has README.md, docs/Architecture.md, docs/Requirements.md, docs/Implementation.md, install/Installation.md | `tools/Show-LCM_InventoryApp.ps1` embeds documents only for a fixed repository list (RollingCalendar, LCM_Tools, LCM_Supervision, BGMSAMVInv, BootEntryManager and every new repository are missing; LCM_Inventory listed twice; stale Installation_LCD) | The viewer offers Docs for every repository, so every repository's documents must be available; the list belongs to the inventory, not to the code |
| B2 | Inventory Viewer in dark mode (live test 2026-11-20) | text in the top third barely readable | contrast of the dark theme too low (not yet analysed) | Displays must be readable in both themes (DisplayStandardsPolicy) |
| B3 | Inventory Explorer (live test 2026-11-20) | the header part is not frozen; it scrolls away | not analysed | header and filters stay visible while the table scrolls (DisplayStandardsPolicy) |
| B4 | Inventory Explorer | the boxes (cards/fields) are far too big | not analysed | compact layout as in the other standard displays |
| B5 | Inventory Explorer and standard displays in general | the dark/light mode switch is missing; it has not been showing in the standard displays for some time | not analysed | every standard display offers the theme switch |
| B6 | Inventory Explorer table | the column headings are not selection drop-downs (no column filters) | not analysed | column headings work as filter drop-downs like in the other tables |
| B7 | Inventory Explorer | contrast is low in some parts and not uniform (extends B2) | not analysed | uniform, readable contrast in both themes |
| B8 | Inventory Explorer, Docs of LCM_AI | the document preview shows only about 10 lines, the space below stays mostly empty; one more line "0 of 4 selected" | not analysed | the preview uses the available height |
| B9 | Inventory Explorer, Docs of LCM_AI | README shows version 10.0.0 | to verify: the README header itself | version alignment (RULE-REV-007 (4)): corrected with the list, not a separate BUG |
| B10 | Inventory Explorer (live test 2026-11-20) | no button back to the Tools Explorer ("Back", in other displays sometimes "Close"), unlike the other displays | not analysed | uniform navigation to the parent display; the hierarchy itself is defined by CRP-381 |
| B11 | `showtools` in the operator's terminal (live test 2026-11-20) | "Invoke-RestMethod: The request was canceled due to the configured HttpClient.Timeout of 5 seconds elapsing"; the Tool Explorer does not open | every open re-renders, unconditionally: `Open-LcmStandardDisplay` (`modules/LcmStandardDisplay.psm1`) always sends `POST /displays/refresh/<id>` and waits 5 s; the daemon (CRP-335) always runs `renderDisplay` and answers only after `Invoke-LcmDisplayRender.ps1` has finished (tools about 7 s, hub 2.7 s). The client's polling loop for state `Current` expects an immediate answer: client and daemon follow different designs. Root cause (operator 2026-11-20): data changes should need no rendering at all; addressed by CRP-382 (live data from SQLite views) | the ShowTools macro opens the Tool Explorer |
| B12 | GoodNight -Push (2026-11-20 00:41:56) | "PUSH requires at least one completed proposal owned by a non-LCM_Inventory repository"; nothing pushed | `modules/LCM_PushEligibility.psm1` reads only `origin_repo` and `affected_repos`; completion (COMPLETE / Submit-ReviewResult) commits several repositories but records `affected_repos` nowhere, and no governed tool can set it (known since the 2026-11-19 push) | operator rule (2026-11-20): everything that was changed MUST be pushed when it is completed - every repository with completed, committed changes ahead of its remote, governed or not; unchanged repositories are simply not pushed. No ownership field: `origin_repo` is the ledger home (RULE-LCM-034), not the target |
| B13 | Control Hub after "accept" of CRP-339 (operator 2026-11-20 13:35) | CRP-339 shown as "1 - Review / undecided" | the hub render of 13:35:55 (`data/artifacts/CM_CONTROL_HUB.html`) carries `state: suggested`, three seconds after the accept (13:35:52); ledger and Specification say `in_progress`: the render read data older than the transition | the hub shows the ledger state; cohort with CRP-382 (live data, no baked render) |
| B14 | registering BUG-384 (2026-11-20) | a new BUG gets priority 5 | `New-LCM_Proposal` defaults every item to 5 | BUGs default to 6 or higher (operator 2026-11-20), CRPs to 5 |
| B15 | `Invoke-ProposalAction -Action priority -Priority 7` (2026-11-20) | refused: only C/H/M/L/D | `ValidateSet` allows letters only (10/8/5/3/1); the ledger range is 0-10 | the CLI sets every ledger priority 0-10 |
| B16 | priority changes of BUG-380, CRP-385, CRP-386 (2026-11-20) | Specification `Priority:` unchanged | `Get-LcmSpecificationStateEdits` mirrors only state changes | the Specification header mirrors the ledger priority |

### Sorting (operator 2026-11-20, Q1 A)

Rule: BUGs are sorted out early (priority 6 or higher), unless a CRP reworks the area or the entry clearly cohorts with a CRP scope.

| Entries | Treatment | Priority |
|:---|:---|:---|
| B1, B12, B13, B14-B16 | stand-alone fixes now (B13: operator Q-B13 A, it corrupts administrative state) | 7 (item) |
| B9 | rides with the release version alignment | - |
| B2-B8, B10 | absorbed into CRP-381 (CRP-382 rebuilds the display pages) | follows CRP-381 |
| B11 | absorbed into CRP-382 (no re-render, live data) | follows CRP-382 |

## 3. Gate 0 Contract

Written per entry when the operator releases the list: target state, exit criterion (operator live test).

## 4. Working In The Same Live Test (2026-11-20 00:20:32)

Search finds LCM_AI; Docs shows its 4 documents; Show, Edit (Notepad++), document type selection and Close work; print not tested.
