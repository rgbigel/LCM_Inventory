# Implementation Plan: BUG-291

Module: docs/Proposals/BUG-291-BUG-Structural-implementation-can-proceed-without/Implementation_Plan.md
Purpose: Describe the planned enforcement repair for the proposal-first governance gap.
Path: D:\Git_Repositories\LCM_Inventory\docs\Proposals\BUG-291-BUG-Structural-implementation-can-proceed-without\Implementation_Plan.md
Authors: Rolf, Copilot
Version: 1.0.1
Status: Remediation implemented and accepted
Date: 2026-10-18

## 1. Root Cause

`Assert-LcmImplementationAllowed` in `AnalysisGovernance.psm1` checks only whether the workspace is in a modifiable analysis mode. It has no repository/proposal parameters and cannot establish that Gate 1 occurred. Structural tools can therefore modify filesystem state without any proposal-state validation.

## 2. Remediation Authority and Delivered Repair

This plan is the authoritative remediation definition for BUG-291. It was implemented as follows:

1. Added `Assert-LcmProposalImplementationEligibility` to `ProposalManager.psm1`.
2. Made the assertion verify matching origin repository, implementation-eligible state, and an existing specification bundle.
3. Required `Invoke-ProposalAction.ps1 -Action new-app` to receive an explicit `-ProposalId` and validate it before App scaffolding.
4. Added/updated Pester coverage for the current lifecycle state contract and verified the proposal-manager suite.
5. Preserved explicit failure output: no inferred proposal selection and no `-Force` bypass.

## 3. Safety Plan

- Do not alter proposal states automatically.
- Do not infer a proposal from arbitrary dirty files or the newest ledger entry.
- Do not introduce a `-Force` override.
- Keep the new check outside read-only analysis and proposal-authoring commands.

## 4. Verification and Closure

The remediation was verified by PowerShell AST parsing, direct negative checks for a suggested proposal and omitted `-ProposalId`, and `ProposalManager.Tests.ps1` with 21 passed and 0 failed. The accepted BCR disposition was recorded and committed as `ea3e886`.

No additional success narrative may be appended to the walkthrough after closure. A new discrepancy must start a new BUG/CRP or linked regression record.
