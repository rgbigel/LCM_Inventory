# Implementation Plan: BUG-364 - Unit Test Failures Surfaced By LCM_Inventory Readiness Gate

Module: docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Implementation Plan BUG-364.md  
Purpose: Planned changes beyond the Specification.  
Path: LCM_Inventory/docs/Proposals/364_BUG-Unit-Test-Failures-Surfaced-By-LCM-Inventory-Readi/Implementation Plan BUG-364.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 11:05:00

---

Nothing beyond the Specification, except the open item below.

- Open: after the operator's lifecycle decision (Specification section 3), adjust `Test-LcmProposalLifecycleTransition` (ProposalManager.psm1) or `tests/ProposalLifecycle.Tests.ps1` (or both) and, for option B, the rule table; then the full gate run and `verified`.
