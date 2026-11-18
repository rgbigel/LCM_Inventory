# Walkthrough: CRP-322 - SQLite Proposals Ledger Engine, Canonical SQL Projection, and LCM Version Grouping

```yaml
CRP-ID: CRP-322
Title: SQLite Proposals Ledger Engine, Canonical SQL Projection, and LCM Version Grouping
Scope: LCM_Inventory
Baseline-Version: 10.2.3
Author: rgbig
Date: 2026-11-12 12:15:00
Status: Verified
Plan-State: in_review
Progress-State: in_review
Priority: 8
```

---

## 1. Executive Summary
CRP-322 introduces an indexed SQLite engine (`proposals.db`) for the proposals subsystem, establishes an authoritative **LCM Version** partitioning taxonomy across all 296 proposals, and implements a **Canonical SQL Text Projection (`proposals.sql`)** with native Git pull/checkout hooks.

This architecture delivers the "best of both worlds":
1. **Sub-millisecond local execution**: Tools and ShowCM read and write directly to SQLite ($< 2\text{ms}$) instead of serializing 750 KB of JSON.
2. **Clean, reviewable Pull Requests & BCR reviews**: Git tracks the deterministic SQL text dump (`proposals.sql`), eliminating binary merge conflicts and repository bloat.
3. **Seamless Git auto-hydration**: Native `post-merge` and `post-checkout` hooks automatically rebuild `proposals.db` upon `git pull` or branch checkout in $\sim 20\text{ms}$.
4. **Sandbox semi-concurrency**: An authoritative `_lcm_db_metadata` table stamps database identity (`workspace_root`, `workspace_role`, `sandbox_id`), ensuring live and sandbox databases are strictly distinguished and cannot cross-contaminate.
5. **ShowCM clutter elimination**: The 215 historical published proposals are hidden by default via the new Release Horizon filter, reducing visible rows from 296 down to 81 active horizon proposals.

---

## 2. Changes Implemented

1. **Authoritative Version Tagging (`data/proposals/proposals.json`)**:
   - Tagged all 296 proposals with an authoritative `lcm_version`.
   - Active series (`10.2.x`): 76 proposals.
   - Historical releases (`10.1.0`, `10.0.0`, `Legacy (<10.0)`): 220 proposals.

2. **SQLite Engine & Metadata Table (`tools/sync_proposals_db.py`)**:
   - Created standalone Python SQLite engine conforming to `PythonRules.md`.
   - Added `_lcm_db_metadata` table (`workspace_root`, `workspace_role`, `sandbox_id`, `lcm_version`).
   - Implemented `--action dump` to emit clean canonical `proposals.sql`.
   - Implemented `--action hydrate` to reconstruct `proposals.db` from `proposals.sql` in $< 20\text{ms}$.
   - Implemented `--action install-hooks` to deploy Git pull/checkout hooks.

3. **PowerShell Cmdlet Façade (`tools/Sync-LcmProposalsDb.ps1`)**:
   - Supports `-Action Sync|Dump|Hydrate|Verify|Query|InstallHooks`.
   - Supports `-WorkspaceRole LIVE|SANDBOX|BASELINE_ARCHIVE` and `-SandboxId`.

4. **Git Auto-Hydration Hooks (`.git/hooks/`)**:
   - Installed `post-merge` and `post-checkout` hooks in `LCM_Inventory/.git/hooks/`.
   - Hooks monitor changes to `proposals.sql` and trigger silent SQLite re-hydration.

5. **Lifecycle Engine Integration (`modules/ProposalManager.psm1`)**:
   - `New-LCM_Proposal`: Automatically stamps new proposals with `GlobalLCMVersion`.
   - `Set-ProposalStore`: Triggers SQLite sync and SQL dump emission silently on write.
   - `Get-LCM_Proposals`: Supports `-Horizon active|all|historical` and `-LcmVersion`.

6. **ShowCM Control Hub UI (`assets/CM_CONTROL_HUB.html`)**:
   - Added **Release Horizon** filter dropdown in the control bar (`Active Horizon`, `All Releases`, `10.2.x`, etc.).
   - Added `ver:<version>` search token support.
   - Added version badge subtitle `${origin_repo} · ${lcm_version}`.

7. **CLI Listing Integration (`tools/Show-LcmControl.ps1`)**:
   - Added `-Horizon` and `-LcmVersion` parameters.
   - Added `LCMVer` column to `-CliMode` table output.

---

## 3. Verification Protocol & Evidence

1. **3-Way Parity Verification**:
   ```powershell
   pwsh tools/Sync-LcmProposalsDb.ps1 -Action Verify
   ```
   **Result**: `[PASS] 100% Dual-State Parity Verified across 296 proposals (JSON <-> DB <-> SQL). Metadata: Role=LIVE, Root=D:\Git_Repositories, Ver=10.2.3`

2. **Hydration from SQL Dump**:
   ```powershell
   pwsh tools/Sync-LcmProposalsDb.ps1 -Action Hydrate
   ```
   **Result**: Database reconstructed with 296 rows in $< 20\text{ms}$.

3. **Pester Test Suite (`tests/Test-LcmProposalsDb.Tests.ps1`)**:
   - 10/10 tests passed (100%):
     - `[+] Should have the SQLite proposals database and canonical SQL text dump on disk`
     - `[+] Should have the python sync engine and PowerShell tool facade on disk`
     - `[+] Should verify 100% 3-way parity between JSON ledger, SQLite database, and SQL dump`
     - `[+] Should verify database metadata table and workspace identity binding`
     - `[+] Should ensure every proposal in proposals.json possesses an authoritative lcm_version`
     - `[+] Should filter historical published proposals in active horizon query mode`
     - `[+] Should support version-specific querying via Get-LCM_Proposals`
     - `[+] Should cleanly re-hydrate SQLite database from canonical proposals.sql text dump`
     - `[+] Should have Git post-merge and post-checkout auto-hydration hooks installed`
     - `[+] Should validate PowerShell AST syntax of all modified tools`

4. **Flake8 Linter**: 0 violations on `sync_proposals_db.py`.
5. **General LCM Readiness Quality Gates**: 6/6 PASSED on `LCM_Inventory`.
