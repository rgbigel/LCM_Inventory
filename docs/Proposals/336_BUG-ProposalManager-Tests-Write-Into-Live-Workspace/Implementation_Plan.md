# Implementation Plan: BUG-336 - ProposalManager Tests Write Into Live Workspace

Module: docs/Proposals/336_BUG-ProposalManager-Tests-Write-Into-Live-Workspace/Implementation_Plan.md  
Purpose: Changes and Gate 0 traceability for BUG-336 (Claude, DOIT).  
Path: LCM_Inventory/docs/Proposals/336_BUG-ProposalManager-Tests-Write-Into-Live-Workspace/Implementation_Plan.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Implemented (DOIT, awaiting Gate 2)  
Date: 2026-11-15 16:42:43

---

| Change | Gate 0 clause |
|:---|:---|
| `tests/ProposalManager.Tests.ps1`: store redirected into TestDrive via `LCM_PROPOSAL_STORE_PATH` (seeded read-only from the live ledger) instead of backup/restore of the live file; env restored in `AfterAll` | Target state (no live writes) |
| Same file: `-WorkspaceRoot $TestDrive` on the four `New-WorkspaceProposal` calls and on `Sync-LcmAppCatalog -Repo 'LCM_AI'` | Target state (bundles, catalog) |
| `modules/ProposalManager.psm1` `Set-ProposalStore`: skip the live DB sync while the store is redirected (the sync always reads the live JSON) | Target state (DB, SQL dump). Revises the Non-Goal "no module behaviour change": this was the remaining leak. |
| `tests/ProposalSpecificationFence.Tests.ps1`: look up `New-LCM_Proposal` (alias `New-WorkspaceProposal` is not a function node) and the new template heading | Exit criterion "suite passes" (3 tests had been failing since the function rename) |