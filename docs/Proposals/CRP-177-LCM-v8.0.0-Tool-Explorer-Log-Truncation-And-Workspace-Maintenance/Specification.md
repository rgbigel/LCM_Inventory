# Change Request Proposal: CRP-177

```yaml
CRP-ID: CRP-177
Title: Tool Explorer Ergonomics, Daemon Log Truncation, and Automated Workspace Maintenance Engine
Scope: .lcm, LCM_Inventory, Tool Explorer UI, Desktop Daemon Logs, Pre-Push Pipeline
Baseline-Version: v8.0.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: Medium
Impacted-Repositories:
  - Git_Repositories
  - LCM_Inventory
```

---

## 1. Executive Summary & Problem Context

During operational use of the LCM Tool Explorer and workspace push lifecycle, multiple usability defects, bloat issues, and ergonomic opportunities were identified:

1. **Tool Explorer UI Clutter & Regressions**:
   - The top KPI metric card area included a redundant `card-noexit` ("NOEXIT LOCKED") button that added noise without clear operational utility.
   - Action buttons and top controls were excessively padded and took up disproportionate screen real estate.
   - Tool names were prefixed with generic pictograms (`📁 `, `💬 `) that hindered clean visual scanning.
   - There was no consistent sequential index or counter to uniquely reference items across filtered and sorted views.
   - Tool subsystem/group classifications could not be edited in-place from the table row, preventing quick human classification triage, and there was no `"Needed?"` tag for cleanup triage.
   - Short-name generation created unwieldy, overly long identifiers (e.g. `HaSSD06InventoryTestRepoReadiness` for `Test-RepoReadiness.ps1`).

2. **Unbounded Desktop Daemon Log Growth**:
   - `LcmDesktopDaemon-*.log` files in `LCM_Inventory/tools/logs` grew continuously without truncation, reaching over 2.7 MB and tens of thousands of lines per session.
   - The daemon's internal log rotation only triggered at 10 MB and only purged files older than 7 days on startup, leaving huge multi-megabyte log files perpetually active.

3. **Absence of Unified Workspace Maintenance Pipeline**:
   - There was no automated maintenance job to purge transient/junk files (`*.tmp`, `*~`), prune stale script logs, and truncate daemon logs to a manageable tail (~100 lines) prior to remote pushes.

---

## 2. Technical Architecture & Modifications

### 2.1 Tool Explorer UI & Ergonomics
- **NoExit Button Removal**: Eliminated `card-noexit` metric card from `LCM_Inventory/modules/LcmToolCatalog.psm1`.
- **Button Compaction**: Updated `LCMToolCatalog.css` (both `LCM_Inventory/assets` and `LCM_Inventory/assets`) reducing button padding (`2px 7px`), font-size (`10px`–`11px`), and compacting top-bar controls.
- **Pictogram Removal & Sequential `#` Counter Column**:
  - Removed decorative icons prefixed to tool names in `lcm-tool-explorer.js`.
  - Added a dedicated `#` column displaying `001-max` (`String(safeIdx + 1).padStart(3, '0')`), representing the unique 1-based sequential index from the master unfiltered list.
- **In-Place Subsystem / Group Editor with "Needed?" Option**:
  - Made the Subsystem column clickable (`openCellEditor(safeIdx, 'Group', event)`).
  - Dynamically populated available subsystems from catalog data, prepending `"Needed?"` to support human cleanup triage.
  - Ensured header and dropdown selectors remain strictly titled **Subsystem** and **All Subsystems**.
- **Short-Name Disambiguation**:
  - Renamed `HaSSD06InventoryTestRepoReadiness` &rarr; **`TestHaRepoReady`** in `LCM_Inventory/tools/Update-ToolCatalog.ps1`.
  - Created `LCM_Inventory/Cmd/TestHaRepoReady.cmd` launcher and purged legacy long companion `.cmd`.

### 2.2 Workspace Maintenance & Daemon Log Truncation Engine
- **Created `Invoke-WorkspaceMaintenance.ps1`**:
  - Canonical implementation: `LCM_Inventory/tools/Invoke-WorkspaceMaintenance.ps1`.
  - Internal runner: `LCM_Inventory/tools/Invoke-WorkspaceMaintenance.ps1`.
  - Command launcher: `LCM_Inventory/Cmd/WorkspaceMaintenance.cmd`.
  - **Core Functions**:
    1. **Log Tail Truncation**: Safely truncates active `LcmDesktopDaemon-*.log` files to the trailing ~100 lines, prepending a structured truncation header with timestamp and original line count. Employs retry loops to handle transient file concurrency gracefully.
    2. **Daemon Log Aging**: Automatically purges daemon logs older than `$MaxLogAgeDays` (default: 7 days) while strictly preserving the newest active log.
    3. **Transient Log Purging**: Prunes transient script logs in `LCM_Inventory/logs` older than `$MaxScriptLogAgeDays` (default: 3 days).
    4. **Beyond Compare Scratch Review Maintenance**: Integrates `Clear-BCReviewTemp.ps1` to clean review scratch folders older than 48 hours while safely preserving `ACTIVE_BASELINE` and `ACTIVE_LIVE` junctions.
    5. **Temporary Junk Pruning**: Prunes temporary junk files (`*.tmp`, `*~`) older than 24 hours.

### 2.3 Pre-Push Pipeline Integration
- Integrated `Invoke-WorkspaceMaintenance.ps1 -TailLines 100` into `LCM_Inventory/tools/Invoke-WorkspacePush.ps1` as Step 0.2, guaranteeing log hygiene and scratch pruning prior to every remote push.

### 2.4 Dedicated Per-CRP Review Sessions & Collision Prevention
- **Eliminated Singleton Junction Clobbering**:
  - Replaced the vulnerable singleton `ACTIVE_BASELINE` / `ACTIVE_LIVE` structure with dedicated per-CRP subdirectories in scratch:
    `LCM_Inventory\scratch\BC_Review\<CRP>\Baseline_<Repo>_<SHA>\` and `Live_<Repo>\` (NTFS junction to repo).
  - Maintained root-level `ACTIVE_BASELINE` and `ACTIVE_LIVE` as convenience mirrors for backward compatibility.
- **Named Session & Breadcrumb Title Alignment**:
  - Dynamically registers and configures dedicated Beyond Compare sessions (e.g. `<CRP>_Review`) in `BCSessions.xml`.
  - Beyond Compare now names the window/tab directly after the proposal (e.g. `CRP-177_Review`) and breadcrumbs explicitly display the exact baseline SHA and live repo target paths, overcoming Beyond Compare 5's CLI limitation where `/title1` and `/title2` are ignored on folder compares.
- **Junction-Safe Scratch Cleanup**:
  - Hardened `Clear-BCReviewTemp.ps1` to explicitly discover and unlink all nested directory junctions via `[System.IO.Directory]::Delete($path, $false)` prior to executing recursive directory deletion, guaranteeing that live repositories are never accidentally modified.

---

## 3. Impact Assessment & Governance Conformance

- **Repository Isolation**: All changes are strictly scoped to `.lcm` and `LCM_Inventory`.
- **PowerShell Compliance**: Adheres to `RULE-PS-001` through `RULE-PS-014` (`Set-StrictMode`, approved verbs, no bare inline ifs, colon-safe string interpolation).
- **Proposal Review Flow**: Follows `RULE-LCM-014` and proposal bundle directory architecture `RULE-LCM-020`.
