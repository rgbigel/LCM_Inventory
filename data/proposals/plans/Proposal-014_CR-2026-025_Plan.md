# Implementation Plan - Proposal #14 (CR-2026-025)
## Dual-State Proposal Lifecycle (Plan State + Progress State) & CM Plan Archive
- Codify RULE-LCM-007: Mandatory separation of Plan State from Implementation Progress State (initial state: undecided).
- Establish persistent CM archive under Workspace_Inventory/data/proposals/plans/.
- Add Set-WorkspaceProposalProgress, Save-ProposalPlan, and Save-ProposalWalkthrough in ProposalManager.psm1.
