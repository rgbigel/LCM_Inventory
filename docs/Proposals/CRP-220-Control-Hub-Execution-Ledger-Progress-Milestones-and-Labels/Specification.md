# Specification: CRP-220 Control Hub Execution Ledger Progress Milestone Synchronization, Action Step Labels, and Dual-Domain Transition Matrix

Module: LCM_Inventory/assets/CM_CONTROL_HUB.html  
Purpose: Resolves Execution Ledger milestone evaluation disconnects, adds interstitial operational action connectors, introduces busy state indicators, and formalizes the dual-domain (internal vs. external) state transition matrix in governance documentation.  
Path: LCM_Inventory/docs/Proposals/CRP-220-Control-Hub-Execution-Ledger-Progress-Milestones-and-Labels/Specification.md  
Authors: rgbig, LCM_AI Governance  
Version: 1.2.0  
Status: Approved  
Date: 2026-10-03  
App: App: 1 - CM Interactive Control Hub  

---

## 1. Problem Statement

When operating within the interactive LCM Control Hub (`ShowCM` / `http://127.0.0.1:9876/hub`):
1. **Milestone Disconnects**: Proposals in active implementation (under two-tier governance: `state: approved`, `progress_state: in_progress` or `progress_state: committed`) exhibited milestone evaluation stalls or regressions, jumping from `In Progress` backward to `Scoped` because `committed` was unmapped in the milestone index.
2. **Missing Operational Action Labels**: The Execution Ledger displayed 7 discrete milestones but lacked visible action connectors indicating which canonical command (`scope`, `approve`, `start`, `verify`, `commit`, `push`) advances a proposal to the next milestone.
3. **Absence of Busy Indication**: Because PowerShell actions (`Invoke-ProposalAction.ps1`, `Invoke-BeyondCompareReview.ps1`) execute asynchronously via the REST Daemon, triggering actions without visual busy feedback gave the false impression that operations failed or hung.
4. **Undocumented Dual-Domain Transitions**: LCM governance documentation lacked an authoritative matrix and graphic capturing BOTH **Internal State Transitions** (CM ledger `state` and physical `progress_state`) and **External State Transitions** (Operator actions and visible UI badge statuses).

---

## 2. Technical Requirements

### 2.1 Progress-Aware Milestone Indexing
The Execution Ledger timeline in `CM_CONTROL_HUB.html` MUST evaluate both `progress_state` and `state`:
- Milestone 6 (`Published`): `prog === "pushed" || st === "pushed"`
- Milestone 5 (`Committed`): `prog === "completed" || st === "completed" || prog === "committed"`
- Milestone 4 (`Verified`): `prog === "verification" || prog === "verified" || st === "review" || test_status === "passed"`
- Milestone 3 (`In Progress`): `prog === "in_progress" || st === "in_progress"`
- Milestone 2 (`Decided`): `st === "approved"`
- Milestone 1 (`Scoped`): Bound repository or assigned bundle
- Milestone 0 (`Suggested`): Intake baseline

### 2.2 Interstitial Action Connector Labels
The timeline flex container MUST render operational action pills between steps:
- Step 0 $\xrightarrow{\text{scope}}$ Step 1
- Step 1 $\xrightarrow{\text{approve}}$ Step 2
- Step 2 $\xrightarrow{\text{start (do)}}$ Step 3
- Step 3 $\xrightarrow{\text{verify (bcr)}}$ Step 4
- Step 4 $\xrightarrow{\text{commit}}$ Step 5
- Step 5 $\xrightarrow{\text{push}}$ Step 6

### 2.3 Interactive Busy Indicator
When dispatching commands via `POST /execute`:
- Display a modal overlay (`#lcmBusyOverlay`) with an animated spinner, operation title, and command details.
- Lock UI pointer events to prevent double-dispatch races.
- Animate the topbar sync indicator (`.sync-dot.busy`) with amber pulsing.
- Automatically dismiss the overlay and restore the cursor upon command completion and data refresh.

### 2.4 Authoritative Dual-Domain State-Action-Transition Matrix
Governance policy (`ProposalReviewFlowPolicy.md`) MUST explicitly document both internal CM states and external operator-visible states with a Mermaid state diagram and tabular matrix.
