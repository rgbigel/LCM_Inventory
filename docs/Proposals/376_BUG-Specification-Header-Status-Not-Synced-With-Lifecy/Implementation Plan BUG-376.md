# Implementation Plan: BUG-376 - Specification Header Status Not Synced With Lifecycle

Module: docs/Proposals/376_BUG-Specification-Header-Status-Not-Synced-With-Lifecy/Implementation Plan BUG-376.md  
Purpose: Concrete changes per file for BUG-376.  
Path: LCM_Inventory/docs/Proposals/376_BUG-Specification-Header-Status-Not-Synced-With-Lifecy/Implementation Plan BUG-376.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 17:56:58

---

| File | Change |
|:---|:---|
| `modules/ProposalSpecificationState.psm1` 10.2.4 | after the YAML update, the first `Status:` line above the fence takes the YAML Status; the line break is kept |
| `tests/ProposalSpecificationState.Tests.ps1` | new case with a DOX header above the fence (header mirrored, line break kept, body untouched) |
| 41 bundle Specifications | one-time alignment of the header Status (list in the Walkthrough) |
