# Implementation Plan: BUG-291

Module: docs/Proposals/BUG-291-BUG-Structural-implementation-can-proceed-without/Implementation_Plan.md
Purpose: Describe the planned enforcement repair for the proposal-first governance gap.
Path: D:\Git_Repositories\LCM_Inventory\docs\Proposals\BUG-291-BUG-Structural-implementation-can-proceed-without\Implementation_Plan.md
Authors: Rolf, Copilot
Version: 1.0.0
Status: Awaiting Gate 1 acceptance
Date: 2026-10-18

## 1. Root Cause

`Assert-LcmImplementationAllowed` in `AnalysisGovernance.psm1` checks only whether the workspace is in a modifiable analysis mode. It has no repository/proposal parameters and cannot establish that Gate 1 occurred. Structural tools can therefore modify filesystem state without any proposal-state validation.

## 2. Planned Repair

1. Add a typed reusable assertion in the proposal lifecycle module for repository/proposal eligibility.
2. Make the assertion verify matching origin repository, lifecycle state, and an existing specification bundle.
3. Call it from the common readiness/commit path and official structural/App scaffolding entry points.
4. Add Pester tests for the allowed and forbidden cases.
5. Update lifecycle documentation so the required input and failure path are visible to operators.

## 3. Safety Plan

- Do not alter proposal states automatically.
- Do not infer a proposal from arbitrary dirty files or the newest ledger entry.
- Do not introduce a `-Force` override.
- Keep the new check outside read-only analysis and proposal-authoring commands.

## 4. Verification Plan

Run targeted Pester tests for proposal lifecycle and workspace-push eligibility, PowerShell AST parsing for touched tools/modules, and the smallest readiness/preview command that exercises the new guard.
