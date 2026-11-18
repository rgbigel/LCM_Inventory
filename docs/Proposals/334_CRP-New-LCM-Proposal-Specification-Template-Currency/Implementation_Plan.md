# Implementation Plan: CRP-334 - New-LCM_Proposal Specification Template Currency

Module: docs/Proposals/334_CRP-New-LCM-Proposal-Specification-Template-Currency/Implementation_Plan.md  
Purpose: Changes and Gate 0 traceability for CRP-334 (Claude, DOIT).  
Path: LCM_Inventory/docs/Proposals/334_CRP-New-LCM-Proposal-Specification-Template-Currency/Implementation_Plan.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Implemented (DOIT, awaiting Gate 2)  
Date: 2026-11-15 16:42:43

---

| Change in `modules/ProposalManager.psm1` (10.2.3 -> 10.2.4) | Gate 0 clause |
|:---|:---|
| Version resolved before any scaffolding: `inventory.json` GlobalLCMVersion, then `<WorkspaceRoot>/LCM_AI/.agents/version.json`, then module-relative `LCM_AI/.agents/version.json`, else throw (no stale `10.2.3` fallback) | Requested change 1, 4 |
| `-Priority <0..10>` (default 5) used for template and ledger row | Requested change 2 |
| Template: DOX header (Module, Purpose, Path, Authors, Version, Status, Date), heading `# Specification: <id>`, `Baseline-Version` = resolved version | Requested change 3 |
| Header: Authors, Version, Date, Implementation Choices | RULE-DOC-011 |

Blocked during verification by BUG-336 (test isolation); fixed there.