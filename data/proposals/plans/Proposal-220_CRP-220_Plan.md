# Implementation Plan: CRP-220 Control Hub Execution Ledger Progress Milestone Synchronization, Action Step Labels, and Dual-Domain Transition Matrix

Module: LCM_Inventory/assets/CM_CONTROL_HUB.html  
Purpose: Step-by-step implementation plan for Execution Ledger milestone evaluation, action transition labels, busy state indicators, and governance matrix documentation.  
Path: LCM_Inventory/data/proposals/plans/Proposal-220_CRP-220_Plan.md  
Authors: rgbig, LCM_AI Engine  
Version: 1.2.0  
Status: Authoritative Implementation Plan  
Date: 2026-10-03  
App: App: 1 - CM Interactive Control Hub  

---

## 1. Proposed Changes

| File | Subsystem | Planned Modifications | Verification Method |
| :--- | :--- | :--- | :--- |
| `LCM_Inventory/assets/CM_CONTROL_HUB.html` | Presentation Template | 1. Update `updateTimelineDisplay()` with progress-aware milestone indexing including `committed` mapping.<br>2. Add action transition connector elements between milestone steps.<br>3. Add full row-click selection trigger `toggleProposalRowSelection()`.<br>4. Implement `#lcmBusyOverlay` with spinner and daemon sync dot pulse.<br>5. Call `updateTimelineDisplay()` in `refreshHubData()`. | Browser inspection & DOM verification |
| `LCM_Inventory/tools/Show-LcmControl.ps1` | Compilation Engine | Scan proposal documents across all workspace repositories into `docsCache`. | Run `Show-LcmControl.ps1 -NoLaunch` |
| `.agents/rules/ProposalReviewFlowPolicy.md` | Governance | Insert the authoritative Dual-Domain (Internal vs. External) State-Action-Transition Matrix & Mermaid diagram. | AST & markdown validation |

---

## 2. Implementation Steps

### Phase 1: Presentation Template Enhancements
1. In `CM_CONTROL_HUB.html`, modify `.timeline` HTML structure to interleave action transition pills (`scope`, `approve`, `start`, `verify`, `commit`, `push`) between milestone steps.
2. In CSS, style `.timeline-action` with subtle action badges, matching active status styling.
3. Update `updateTimelineDisplay()` to evaluate both `progress_state` (including `committed` $\rightarrow$ Milestone 5) and `state`.
4. Add `toggleProposalRowSelection(event, id)` to `<tr>` elements so clicking a row anywhere selects the item and immediately updates the Execution Ledger.
5. Implement `showBusyIndicator(title, details)` and `hideBusyIndicator()` to provide instant visual feedback during daemon command execution.
6. In `refreshHubData()`, call `updateTimelineDisplay()`.

### Phase 2: Proposal Document Cache Aggregation
1. In `Show-LcmControl.ps1`, fix `$repoDirs` loop variable to scan proposal markdown documents across all repositories (`LCM_AI`, `LCM_Inventory`, `RollingCalendar`).

### Phase 3: Governance Documentation
1. In `ProposalReviewFlowPolicy.md`, add a dedicated section containing the Dual-Domain (Internal vs. External) State-Action-Transition Matrix and Mermaid state diagram.
