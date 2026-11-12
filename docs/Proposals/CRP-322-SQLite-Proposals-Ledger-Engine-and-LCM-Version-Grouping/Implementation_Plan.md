# Implementation Plan: CRP-322 - SQLite Proposals Ledger Engine and LCM Version Grouping

```yaml
CRP-ID: CRP-322
Title: SQLite Proposals Ledger Engine and LCM Version Grouping
Scope: LCM_Inventory
Baseline-Version: 10.2.3
Author: rgbig
Date: 2026-11-12 10:07:00
Status: Verified
Plan-State: in_review
Progress-State: in_review
Priority: 8
```

---

## 1. Executive Summary & Problem Context
CRP-322 implements SQLite storage and release-version partitioning for the proposals subsystem in `LCM_Inventory`. It eliminates operator clutter from 220 historical published proposals in ShowCM and provides sub-millisecond query performance via a dual-state projection SQLite database (`data/proposals/proposals.db`).

---

## 2. Gate 0 Traceability & Milestones
- **Milestone 1: Proposals Ledger Version Tagging**:
  Enrich all 295 proposals in `proposals.json` with an explicit `lcm_version` tag based on specification headers, push dates, and release boundaries.
- **Milestone 2: SQLite Schema & Projection Utility (`Sync-LcmProposalsDb.ps1`)**:
  Build `LCM_Inventory/tools/Sync-LcmProposalsDb.ps1` using Python's built-in SQLite 3 engine or Go/PowerShell wrapper to project `proposals.json` into `proposals.db` with indexes.
- **Milestone 3: Proposal Lifecycle Engine Integration (`ProposalManager.psm1`)**:
  Update `New-LCM_Proposal` to auto-stamp the active `GlobalLCMVersion`. Integrate SQLite projection trigger upon proposal state changes.
- **Milestone 4: ShowCM UI Enhancement (`CM_CONTROL_HUB.html`)**:
  Add `Release Horizon` dropdown filter to the Control Hub topbar/filters with options:
  - `Active Horizon (Current 10.2.x)` [Default]
  - `All Releases (Complete History)`
  - Individual version filters (`10.2.x`, `10.1.0`, `10.0.0`, `Legacy (<10.0)`)
  Add `LCM Ver` badge column to proposal table.
- **Milestone 5: Verification & Quality Gates**:
  Execute sync verification, database queries, Control Hub re-compilation, and 6/6 LCM general readiness quality gates.

---

## 3. Detailed Component Plan

### Component 1: `LCM_Inventory/tools/Sync-LcmProposalsDb.ps1`
- Read `data/proposals/proposals.json`.
- Initialize/connect to `data/proposals/proposals.db`.
- Create `proposals` table and indexes.
- Bulk upsert proposals using transactions for maximum speed ($< 50\text{ms}$).
- Output verification report (row counts, version breakdown).

### Component 2: `LCM_Inventory/assets/CM_CONTROL_HUB.html`
- Add Horizon dropdown in Filter Bar.
- Filter logic:
  If `horizonFilter === 'active'`, exclude proposals where `state === 'pushed'` AND `lcm_version` is NOT in active series (`10.2.0`, `10.2.1`, `10.2.2`, `10.2.3`). Active, in-progress, or held proposals always show regardless of version.
- Re-render table with version column badge.

### Component 3: CLI & Module Updates (`ProposalManager.psm1`)
- Support `-LcmVersion` in `Get-LCM_Proposals`.
- Support `-ActiveHorizon` switch.
- Auto-tag new proposals with current `GlobalLCMVersion`.
