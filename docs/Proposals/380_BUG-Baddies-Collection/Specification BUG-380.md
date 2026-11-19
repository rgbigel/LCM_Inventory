# Specification: BUG-380

Module: docs/Proposals/380_BUG-Baddies-Collection/Specification BUG-380.md  
Purpose: Baddies Collection  
Path: LCM_Inventory/docs/Proposals/380_BUG-Baddies-Collection/Specification BUG-380.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 00:08:47

```yaml
CRP-ID: BUG-380
Title: Baddies Collection
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-20 00:08:47
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
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

## 3. Gate 0 Contract

Written per entry when the operator releases the list: target state, exit criterion (operator live test).

## 4. Working In The Same Live Test (2026-11-20 00:20:32)

Search finds LCM_AI; Docs shows its 4 documents; Show, Edit (Notepad++), document type selection and Close work; print not tested.
