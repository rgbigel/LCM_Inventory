# Change Request Proposal: CRP-186

## Metadata Header
* **Proposal ID**: `CRP-186`
* **Title**: Batch Review Tag Condensation and Proposal State Ledger Synchronization
* **Author**: Rolf, Antigravity AI Assistant
* **Date**: 2026-09-27
* **Status**: In-Progress
* **Target Repositories**: `Workspace_Inventory`
* **App Context**: `A7` (Proposal Management / LCM Hub)
* **Lifecycle State**: In-Progress (DOIT Mode activated)

---

## 1. Executive Summary & Intent
When operators select multiple Change Request Proposals or Defect Reports (e.g. `BUG-183`, `CRP-184`, `BUG-185`) in the Configuration Management Control Hub (`CM_CONTROL_HUB.html`) and invoke **Do Review**, the review tag previously formatted as an excessively long string `BUG-183+CRP-184+BUG-185`. This proposal implements concise, intelligent tag condensation (e.g. `CRP-183-185` for contiguous ranges, or `CRP-183+185` for non-contiguous sets) for Beyond Compare review sessions and directory naming.

Additionally, this proposal corrects the bookkeeping omission where proposal 184 remained in the `suggested` (undecided) state despite its implementation having completed, synchronizing the authoritative `proposals.json` ledger.

---

## 2. Problem Statement
1. **Excessively Long Review Tags**:
   - Compounding multi-proposal tags into `BUG-183+CRP-184+BUG-185` creates clumsy tab titles in Beyond Compare and verbose NTFS folder paths under `Workspace_Inventory/scratch/BC_Review/`.
   - Operators prefer concise range notation such as `CRP-183-185` for contiguous spans, or compact joined notation `CRP-182+185`.
2. **Proposal 184 Bookkeeping Desynchronization**:
   - `CRP-184` ("Tool Explorer Runtime Dropdown Column Dynamic Auto-Widening") was implemented in the working tree, but its state in `Workspace_Inventory/data/proposals/proposals.json` remained `suggested` (`progress_state: "suggested"`).
   - In CM Control Hub, this caused proposal 184 to remain categorized under "Undecided" instead of active/completed work.
3. **Completed Filter Inadvertently Including Pushed Proposals**:
   - In `CM_CONTROL_HUB.html`, the `progState === "completed"` table filter condition previously allowed pushed proposals (`p.state === "pushed" || p.progress_state === "pushed"`) to pass through, causing all 169 pushed proposals to clutter the display when the user filtered for "Completed".

---

## 3. Scope of Modifications
1. **CM Control Hub (`Workspace_Inventory/assets/CM_CONTROL_HUB.html`)**:
   - Add `formatBatchReviewTag(proposals, defaultRepo)` helper to condense multiple selected proposals into concise range strings (`CRP-183-185`).
   - Integrate `formatBatchReviewTag` into `executeBatchReview()`.
   - Fix `progState === "completed"` table filter and `valCompleted` metric counter to strictly exclude pushed proposals.
2. **Proposal Ledger (`Workspace_Inventory/data/proposals/proposals.json`)**:
   - Advance proposal 184 from `suggested` to `in_progress` / `reviewed`.
   - Register `CRP-186` as an active proposal in `proposals.json`.

---

## 4. Architectural Invariants
* **RULE-LCM-020**: Triple documentation files (`Specification.md`, `Implementation_Plan.md`, `Walkthrough.md`) in dedicated bundle directory `Workspace_Inventory/docs/Proposals/CRP-186-Batch-Review-Tag-Condensation-And-Ledger-Sync/`.
* **Zero Disruption to Single Reviews**: Single proposal reviews retain their exact native tags (e.g. `BUG-183` or `CRP-184`).
* **NTFS Safety**: Generated range strings (`CRP-183-185`) contain only alphanumeric and hyphen characters, guaranteeing 100% path safety for directory names and Beyond Compare XML session values.
