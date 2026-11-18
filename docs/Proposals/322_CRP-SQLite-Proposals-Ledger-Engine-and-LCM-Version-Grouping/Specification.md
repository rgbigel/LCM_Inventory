# Change Request Proposal: CRP-322

```yaml
CRP-ID: CRP-322
Title: SQLite Proposals Ledger Engine, Canonical SQL Projection, and LCM Version Grouping
Scope: LCM_Inventory
Baseline-Version: 10.2.3
Author: rgbig
Date: 2026-11-12 12:15:00
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Gate-1: Accepted (2026-11-12 09:57:20)
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
Advance the introduction of SQLite by modernizing the proposals subsystem under a **Dual-State Projection** model that solves both runtime efficiency and version control / sandbox isolation. Out of 296 proposals currently tracked in `proposals.json`, 258 are published/pushed, with 215 originating in legacy and historical releases prior to LCM 10.2.0.

CRP-322:
1. Establishes an explicit **LCM Version** taxonomy across all proposals, hiding historical published releases by default in ShowCM (`CM_CONTROL_HUB.html`) and CLI queries.
2. Implements a high-performance local SQLite database (`data/proposals/proposals.db`) equipped with a `_lcm_db_metadata` table for workspace and sandbox identity binding.
3. Generates a deterministic, sorted canonical text dump (**`data/proposals/proposals.sql`**) tracked in Git for human-readable GitHub Pull Requests and Beyond Compare (BCR) diffs without binary repo bloat.
4. Deploys Git **`pre-push`**, **`post-merge`**, and **`post-checkout`** hooks in `.githooks/` that guarantee deterministic export of `proposals.sql` before pushing upstream and auto-hydrate local `proposals.db` in $\sim 20\text{ms}$ upon pull or checkout.
5. Establishes the authoritative retirement path for `proposals.json`, designating SQLite as the definitive ledger engine and `proposals.sql` as its Git text projection.

---

## 2. Gate 0 Contract

### Target State
1. **Explicit Version Attribution**: Every proposal in `proposals.json` and `proposals.db` possesses an authoritative `lcm_version` property (e.g., `10.2.3`, `10.2.2`, `10.2.1`, `10.2.0`, `10.1.0`, `10.0.0`, `Legacy (<10.0)`).
2. **Automatic Version Inheritance**: New proposals (`New-LCM_Proposal`, `Invoke-ProposalAction.ps1 -Action bug/suggest`) automatically inherit the active `GlobalLCMVersion` from `data/inventory.json`.
3. **SQLite Proposals Database with Sandbox Isolation**: An indexed SQLite database (`LCM_Inventory/data/proposals/proposals.db`) containing a `_lcm_db_metadata` table (`workspace_root`, `workspace_role`, `sandbox_id`, `lcm_version`) that prevents cross-talk between live and sandbox workspaces.
4. **Canonical SQL Text Projection (`proposals.sql`)**: Deterministic, sorted SQL text export tracked in Git, ensuring clean line-by-line diffs in PRs and BCR visual reviews while `.db` binaries remain git-ignored.
5. **Git Publishing & Auto-Hydration Hooks**: Native `.githooks/pre-push`, `post-merge`, and `post-checkout` hooks. The `pre-push` hook guarantees deterministic export of `proposals.sql` before any push, while `post-merge` and `post-checkout` reconstruct local `proposals.db` when `proposals.sql` changes during pull or branch checkout.
6. **ShowCM Release Horizon Filtering**: The Control Hub UI features a Release Horizon filter dropdown defaulting to `Active Horizon (Current 10.2.x)` that hides published historical proposals (`< 10.2.0`), while keeping all open/in-progress/held items visible across any release.
7. **CLI & Module Filtering**: `Get-LCM_Proposals` and `Show-LcmControl.ps1` support `-Horizon` and `-LcmVersion` switches.

### Invariants and Exit Criteria
- **JSON Retirement Roadmap Invariant**: `proposals.json` is retained strictly as a temporary compatibility bridge during initial SQLite verification. As soon as all tools (`ProposalManager.psm1`, `Invoke-LCM_Push.ps1`, `Show-LcmControl.ps1`) transition to direct SQLite queries, `proposals.json` will be permanently retired, leaving `proposals.db` (local binary engine) and `proposals.sql` (tracked Git text projection) as the sole ledger.
- **3-Way Parity Invariant**: `Sync-LcmProposalsDb.ps1 -Action Verify` validates row count and checksum parity across JSON, SQLite DB, and SQL dump.
- **Fail-Closed Sandbox Invariant**: Databases stamped with a sandbox identity fail closed if accessed by a conflicting workspace.
- **Sub-10ms Query Performance**: SQLite index lookups execute in $< 5\text{ms}$.
- **Readiness Quality Gate Pass**: All files pass PowerShell AST parsing, `flake8` linter, and 6/6 LCM general readiness quality gates.

---

## 3. Schema & Metadata Architecture

```sql
CREATE TABLE IF NOT EXISTS _lcm_db_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS proposals (
    id INTEGER PRIMARY KEY,
    crp_id TEXT NOT NULL UNIQUE,
    lcm_version TEXT NOT NULL,
    state TEXT NOT NULL,
    progress_state TEXT,
    priority INTEGER DEFAULT 5,
    origin_repo TEXT,
    title TEXT NOT NULL,
    details TEXT,
    author TEXT,
    created_at TEXT,
    pushed_at TEXT,
    bundle_dir TEXT,
    disposition TEXT,
    flow_mode TEXT,
    is_active INTEGER DEFAULT 0,
    is_historical INTEGER DEFAULT 0,
    raw_json TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_proposals_lcm_version ON proposals(lcm_version);
CREATE INDEX IF NOT EXISTS idx_proposals_state ON proposals(state);
CREATE INDEX IF NOT EXISTS idx_proposals_is_active ON proposals(is_active);
CREATE INDEX IF NOT EXISTS idx_proposals_is_historical ON proposals(is_historical);
CREATE INDEX IF NOT EXISTS idx_proposals_priority ON proposals(priority);
CREATE INDEX IF NOT EXISTS idx_proposals_origin_repo ON proposals(origin_repo);
```
