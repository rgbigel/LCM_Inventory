# Specification: CRP-265 - Control Hub Rich Action Feedback, Action Consolidation, and Detailed Status Message Area

## 1. Problem Statement
1. In ShowCM (LCM Control Hub), action buttons and automated dispatches report outcomes with brief status indicators (e.g. OK, NOK, Error) without substantive diagnostic context.
2. The lifecycle actions **retire** (`withdraw`) and **supersede** are missing in the 2 key places where they should be directly invocable: the single proposal action menu (top / table row dropdown) and the batch action area (bottom).
3. The bottom area currently contains redundant and duplicated action sections (separate cohort action grid and separate bulk action grid), which unnecessarily wastes screen real estate and fragments operator workflows.
4. Emergency and override switches lack a direct `Testing OFF` switch (unconditional test bypass) alongside `MinimalTests` and `Force`.

## 2. Objective
1. **Rich Action Feedback & Status Messaging**:
   - Provide a dedicated, prominent message and execution log area within the UI to display descriptive outcome information (tool name, command executed, exit code, execution duration, and structured diagnostic text).
   - Replace bare binary indicators (OK/NOK/Error) with real information explaining what occurred and suggesting next lifecycle steps.
2. **Action Layout Separation & Consolidation**:
   - **Single CRP Actions (Top Only)**: Consolidate all available lifecycle actions for individual proposals in the top row / inspector dropdown (proceed, do, bcr, accept review, hold, reopen, complete, commit, push, **retire/withdraw**, and **supersede**).
   - **Batch Actions (Bottom Only)**: Eliminate redundant double sections at the bottom. Consolidate cohort management and batch proposal actions into a unified, space-efficient single bottom action bar with full batch support (including batch **retire** and **supersede**).
3. **Retire & Supersede Implementation**:
   - Wire up `retire` (`withdraw`) and `supersede` to prompt for required details / replacement target and dispatch `Invoke-ProposalAction.ps1 -Action withdraw` / `-Action supersede`.
4. **Testing OFF Switch Integration**:
   - Incorporate a direct `Testing OFF` (`testing-mode paused`) switch into the action and override workflows, distinct from `MinimalTests`.

## 3. Scope & Affected Components
- `LCM_Inventory/assets/CM_CONTROL_HUB.html` (UI layout, status message area, action consolidation, dropdown menus)
- `LCM_Inventory/tools/Show-LcmControl.ps1`
- `LCM_Inventory/modules/ProposalManager.psm1` & `LCM_Inventory/tools/Invoke-ProposalAction.ps1`
- `LCM_Inventory/modules/LcmProgressAtom.psm1`

## 4. Invariants
- 100% backward compatible with Port 9876 REST Daemon execution model.
- Conforms to RULE-DSP-001 through RULE-DSP-016 (Display Standards Policy).
- Adheres to RULE-REV-001 and RULE-LCM-023 governance invariants.

