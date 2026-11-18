# Implementation Plan: BUG-340 - New-LCM_Proposal Placeholder Slug and Version Defects

Date: 2026-11-18 13:23:21

## Changes in `modules/ProposalManager.psm1` (10.2.4 -> 10.2.5)
- `New-LCM_Proposal`
  - Version: reads `LCM_AI/.agents/version.json` first, `data/inventory.json` only as fallback (point 3).
  - Folder: a slug over 50 characters is shortened with a notice naming both names; an existing folder `docs/Proposals/<ID>-*` is reused; two such folders stop the registration (point 2).
  - Specification template: adds "- Review: this Specification only (Plan and Walkthrough not written yet)." under the intake; drops the generic section "3. Technical Requirements & Invariants" (BUG-353).
  - Plan and Walkthrough templates: header, `Status: Placeholder`, `Date:`, one-line note; no intake text (point 1, BUG-353).
- New internal `Get-LcmProposalPlaceholderDocuments`: names the bundle documents that still carry `Status: Placeholder`.
- `Move-LcmProposalLifecycleState`: on `verified`, writes a warning with those names (point 1).

## Tests
- New `tests/ProposalScaffold.Tests.ps1` (5 tests, isolated store and workspace).