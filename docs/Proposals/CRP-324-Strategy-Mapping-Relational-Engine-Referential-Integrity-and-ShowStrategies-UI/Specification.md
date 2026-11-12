# Specification: CRP-324

## Document Information
- **Proposal ID**: `CRP-324`
- **Title**: Strategy Mapping Relational Engine, Referential Integrity Validation, and ShowStrategies UI
- **Author**: Rolf & Antigravity (LCM Governance)
- **Status**: Draft (Awaiting Gate 1 Operator Review)
- **Date**: 2026-11-12
- **Target Repository**: `LCM_Inventory`
- **Impacted Subsystems**: `LCM_Inventory`, `LCM_AI`, `ShowCM` (`CM_CONTROL_HUB`), SQLite Ledger (`proposals.db`), `ShowStrategies`

---

## 1. Executive Summary & Problem Statement

As complex architectures evolve across the LCM workspace, multiple distinct CRPs often share a common strategic horizon (e.g. tool discovery, daemon IPC, decision cascades, repository topology). Combining them into a single monolithic CRP creates unwieldy change sets, inflates review blast radius, and violates `RULE-LCM-027` (Strict Proposal Scope Boundary). Conversely, developing each CRP in complete isolation risks architectural dead-ends.

To solve this, LCM requires a first-class **Strategy Mapping Engine**:
1. **Persistent Strategy Entity**: A Strategy defines a long-range architectural orientation composed of multiple distinct, decoupled CRPs.
2. **Referential Integrity & Consistency Constraint**: Every CRP referenced by a Strategy MUST exist and MUST NOT be in a terminal non-delivering state (`rejected`, `superseded`, `cancelled`). If a constituent CRP fails or is rejected, the Strategy MUST immediately flag an integrity alert.
3. **Dedicated Visualization (`ShowStrategies`)**: Operators require a clear, high-level strategic dashboard reachable directly from `ShowCM` to monitor strategic progress, constituent CRP completion, and horizon goals.

---

## 2. Core Architectural Invariants

### Invariant 1: Relational Schema in `proposals.db`
The proposals database (`LCM_Inventory/data/proposals/proposals.db`) is extended with two relational tables:
- **`strategies`**:
  - `strategy_id` (TEXT PRIMARY KEY, e.g. `'STRAT-001'`)
  - `title` (TEXT NOT NULL)
  - `description` (TEXT)
  - `state` (TEXT NOT NULL, e.g. `'active'`, `'completed'`, `'held'`)
  - `created_at` (TEXT NOT NULL)
  - `updated_at` (TEXT NOT NULL)
- **`strategy_crps`**:
  - `strategy_id` (TEXT NOT NULL, REFERENCES `strategies(strategy_id)`)
  - `crp_id` (TEXT NOT NULL, REFERENCES `proposals(crp_id)`)
  - `goal_role` (TEXT NOT NULL, e.g. `'delivers'`, `'aligns'`, `'prerequisite'`)
  - `PRIMARY KEY (strategy_id, crp_id)`

### Invariant 2: Referential Integrity & Active Status Constraint
A Strategy is valid IF AND ONLY IF all of its referenced CRPs satisfy:
1. `crp_id` exists in the `proposals` table.
2. `state NOT IN ('rejected', 'superseded', 'cancelled')`.
3. If a constituent CRP transitions to `rejected` or `cancelled`, the Strategy enters an `integrity_alert` state and visually surfaces the broken reference.

### Invariant 3: Dual-State Projection Architecture
Conforming to `CRP-322`, the strategy mapping engine supports dual-state projection:
- **Binary Runtime Engine (`data/proposals/proposals.db`)**: High-performance SQLite tables loaded instantly by `ShowStrategies` and `ShowCM`.
- **Canonical Text Projection (`data/proposals/strategies.json` / `strategies.sql`)**: Human-readable and diffable in Beyond Compare 5 (`bcr`).
- Bidirectional synchronization managed via `Sync-LcmStrategiesDb.ps1`.

### Invariant 4: `ShowStrategies` Dashboard & `ShowCM` Navigation Integration
- **`ShowStrategies`** (`ShowStrategies.html` / `Show-Strategies.ps1`):
  - Displays strategic cards: Strategy ID, Title, Status chip, overall completion progress bar, and list of constituent CRP chips with state indicators.
  - Clicking any CRP chip opens its proposal details in `ShowCM`.
- **`ShowCM` Integration**:
  - The `CM_CONTROL_HUB.html` Topbar / Status Rail gains a **`Strategies`** navigation pill.
  - The proposal inspector view displays the Strategy badge if the active CRP belongs to a strategy.

---

## 3. Migration Plan & Impact Analysis

1. **Database Schema Migration**:
   - Extend SQLite schema in `Sync-LcmProposalsDb.ps1` / `sync_proposals_db.py` to create `strategies` and `strategy_crps` tables.
   - Author canonical text projection `strategies.json` and SQL dump.
2. **Integrity Validation Atom**:
   - Create `Test-LcmStrategyConsistency.ps1` to assert referential integrity.
3. **UI Implementation**:
   - Build `ShowStrategies.html` and launch trampoline `Show-Strategies.ps1` (`ShowStrategies.cmd`).
   - Add navigation link in `CM_CONTROL_HUB.html`.
4. **Initial Seed Strategies**:
   - Populate `STRAT-001` through `STRAT-005` based on current unfinished business.

---

## 4. Acceptance Criteria (Gate 1 Gatepost)
- [ ] `strategies` and `strategy_crps` tables exist in `proposals.db`.
- [ ] `Test-LcmStrategyConsistency.ps1` successfully validates referential integrity against non-rejected proposals.
- [ ] `ShowStrategies` renders all active strategies and their constituent CRPs.
- [ ] `ShowCM` contains a visible, functional navigation path to `ShowStrategies`.
- [ ] Dual-state sync between `strategies.json`, SQLite DB, and SQL projection is verified.
- [ ] General Readiness passes 6/6 gates across all governed repositories.

