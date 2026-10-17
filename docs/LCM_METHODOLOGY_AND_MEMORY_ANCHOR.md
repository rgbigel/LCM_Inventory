# Lifecycle Model (LCM) Methodology & Memory Anchor

Module: docs/LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md  
Purpose: Authoritative architectural memory anchor, governance methodology, and operational principles for the multi-repo LCM platform.  
Path: LCM_Inventory/docs/LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md  
Authors: Rolf, LCM_AI Engine  
Version: 10.0.0
Date: 2026-10-13

---

## 1. Executive Summary & Core Methodology

The **Lifecycle Model (LCM)** architecture is anchored upon deterministic reproducibility, unambiguous governance, and an unbroken audit ledger. This document codifies the operational insights and core invariants governing the platform across all repositories in `D:\Git_Repositories\`.

```
==========================================================================
                     LCM METHODOLOGY & MEMORY ANCHOR
==========================================================================
  1. DOX Invariant        : All documenting & code assets are binding.
  2. Ledger Invariant     : Historical logs & receipts are precious memory.
  3. Review Gate Separation: BCR is human visual review; not .gitignore.
  4. Approach 1 Governance: Physical tracking in LCM_Inventory/.agents; junctions on disk.
  5. Snapshot Push Pipeline: Pre-push validation ensures restorable disaster recovery.
  6. Display Table Channel: Port 9876 REST bridge for all LCD browser tables.
==========================================================================
```

---

## 2. The DOX Invariant: Code vs. Data Boundaries

### 2.1 The Principle
In an LCM-governed workspace, **anything that documents or executes is binding across the entire system**.
* Every script (`*.ps1`, `*.psm1`, `*.py`, `*.cmd`), stylesheet (`*.css`), application script (`*.js`), schema (`*.json`), and specification document (`*.md`) represents authoritative governance intent.
* **No code anywhere in a governed workspace is exempt from visual review or Git tracking.**

### 2.2 The Exemption Boundary
The only items exempt from visual review and permanent version tracking are:
1. **Regenerable Scratchpad Artifacts**: Dynamically compiled HTML viewers in `LCM_Inventory/scratch/` (e.g. `SHOW_TOOLS.html`, `User_Tools_Explorer_LCM.html`) that are generated on the fly by tool indexers.
2. **Temporary Execution Buffers**: Local temporary lock files (`*.lock`), PID manifests, and volatile swap files (`*.swp`, `*.tmp`).
3. **Local Tool Symlinks**: Platform symlinks in `LCM_Inventory/Cmd/`.

Everything else—specifically all configurations, metadata, rules, and historical audit logs—is part of the permanent system state.

---

## 3. The Ledger Invariant: Audit Logs as Permanent Memory

### 3.1 Logs are the Memory of the System
Audit logs in LCM are not disposable console output; they constitute the **Configuration Management Ledger**:
* **Daemon Audit Logs** (`LCM_Inventory/tools/logs/LcmDesktopDaemon-*.log`): Record every REST call, tool execution, process dispatch, and client interaction.
* **Tool Execution Logs** (`LCM_Inventory/data/logs/lcm/Show-ToolIndex-*.log`, `Update-ToolCatalog-*.log`, `Sync-GeminiInbox-*.log`): Capture telemetry of metadata compilation, catalog reconciliation, and inbox synchronization.
* **CM Activity Ledger** (`LCM_Inventory/logs/cm_activity.log`): Append-only chronological record of every review disposition, commit SHA, proposal state transition, and repository push.
* **Visual Review Receipts** (`LCM_Inventory/data/reviews/review_*.json`): Cryptographic evidence receipts linking each Beyond Compare visual review session to its resulting Git commit.

### 3.2 Version Control & Snapshot Mandate
* All historical and active logs in `LCM_Inventory/data/logs/lcm/` and `LCM_Inventory/tools/logs/` must be explicitly allow-listed in root `.gitignore` (`!/LCM_Inventory/data/logs/lcm/*.log`).
* These logs must be staged, committed, and pushed as part of repository snapshots so that historical causality is preserved across disaster recovery.

---

## 4. Visual Review Isolation vs. Git Ignore Policies

### 4.1 Strict Conceptual Separation
A critical failure mode identified in platform evolution was the conflation of the Beyond Compare visual review filter with Git's `.gitignore`:
* **Git Ignore (`.gitignore`)**: Controls repository object storage and remote synchronization boundaries.
* **Macrium BCR Review Gate (`Invoke-MacriumBcrReview.ps1`)**: An interactive human inspection flow using the writable Macrium baseline and the Beyond Compare 5 `_LCM` profile.

### 4.2 The BCR Inclusion Rule
* The Macrium BCR flow reviews the actual live Git root; it does not create a scratch live-directory bridge.
* The `_LCM` profile must present all modified durable source and documentation content for operator review.

---

## 5. Canonical Governance Tracking Architecture (Approach 1)

### 5.1 Physical vs. Virtual Repositories
The workspace operates under the NTFS Directory Junction pattern to ensure single-source-of-truth rule discovery:

```
Physical Storage (Canonical):
  D:\Git_Repositories\LCM_Inventory\.agents\
    ├── rules\                    (17 Authoritative LCM Rules)
    ├── hooks.json                (Global Antigravity Hook Bindings)
    ├── mcp_config.json           (Model Context Protocol Server Config)
    ├── ACTIVE_SESSION.md         (Live Session Memory State)
    └── ACTIVE_CONTEXT.md         (Active Task Context)

Virtual Junctions (NTFS Reparse Points):
  D:\Git_Repositories\.agents                  ───►  LCM_Inventory\.agents
  D:\Git_Repositories\LCM_Inventory\.agents ───►  LCM_Inventory\.agents
  D:\Git_Repositories\HaSSD06\.agents\rules       ───►  LCM_Inventory\.agents\rules
  D:\Git_Repositories\<ChildRepo>\.agents\rules   ───►  LCM_Inventory\.agents\rules
```

### 5.2 Approach 1 Git Tracking Invariant
1. **Git Tracks Physical Path**: Version control tracks files strictly under `LCM_Inventory/.agents/*`.
2. **Root Junction Excluded in Git**: The root virtual path `/.agents/` is excluded in root `.gitignore` to prevent Windows NTFS junction collision and duplicate index tracking.
3. **Disaster Recovery Bootstrapping**: A clean `git clone` restores `LCM_Inventory/.agents/` with 100% fidelity. Workspace bootstrap utilities (`Sync-ToolSymlinks.ps1` / `Invoke-LcmSessionAudit.ps1`) verify and recreate the root junction automatically.

---

## 6. The Restorable Snapshot Push Pipeline

### 6.1 Multi-Repository Snapshot Invariant
When `Invoke-WorkspacePush.ps1` runs, it produces a **coherent, cross-repository baseline snapshot**:

1. **Phase 1: Pre-Push Governance Synchronization (`RULE-LCM-013`)**:
   * Consolidates all 17 rules into `LCM_AI/docs/LCM_Rules_Gemini_Export.md`.
   * Mirrors code and tripartite specifications to Google Drive (`D:\GDrive\LCM`).
   * Queries and processes incoming directives in `D:\GDrive\LCM\INBOX`.
   * Automatically stages and commits any updated AI export artifacts.

2. **Phase 2: Metadata & Catalog Snapshot**:
   * Runs `Update-ToolCatalog.ps1 -Silent` to synchronize `tool_catalog.json` and command trampolines in `LCM_Inventory/Cmd/`.
   * Stages and commits catalog updates before push dispatch.

3. **Phase 3: Ahead-Check & Atomic Push**:
   * Inspects all governed repositories for local commits ahead of remote tracking branches.
   * Dispatches `git push origin <branch>` sequentially across all modified repositories.

4. **Phase 4: Post-Push Ledger Finalization**:
   * Transitions completed proposals in `proposals.json` from `completed` to `pushed` with immutable timestamps.
   * Appends a structured `PUSH_EXECUTED` event to `logs/cm_activity.log`.

5. **Dry-Run Simulation Guard (`-DryRun` / `-WhatIf`)**:
   * Enables complete pre-push execution, ahead-detection, and proposal transition simulation without modifying remote repositories.

---

## 7. Browser Display Table Communication Standard (Port 9876 Channel Compliance)

### 7.1 The Architectural Rule
All browser-rendered user interfaces, tool explorers, and tabular components across the LCM ecosystem (such as the LCM Tool Explorer `User_Tools_Explorer_LCM.html`, CM Control Hub `CM_CONTROL_HUB.html`, and Table Print Atom `lcm-table-print-atom.js`) **must communicate host actions strictly through the local Port 9876 REST Bridge Daemon**.

* **Endpoint Authority**: `http://127.0.0.1:9876/`
* **Daemon Provider**: `LCM_Inventory/tools/LcmDesktopDaemon.ps1`
* **Architecture Rationale**: Browser JavaScript executing from `file://` URIs is security-sandboxed and cannot invoke host operating system binaries, native editors, printers, or PowerShell commands directly. Attempting to bypass the daemon via ad-hoc browser popups or inline eval violates system integrity and creates unrepeatable, broken user flows.

### 7.2 Standard API Endpoints
All LCD display table interactions map to standardized daemon REST controllers:
* `POST /launch_tool`: Dispatches a tool from `tool_catalog.json` by `ToolId` via elevated or standard PowerShell runner.
* `POST /open_editor`: Opens specified files in the configured system editor (Notepad++ / VS Code) with file modification watch.
* `POST /print` & `POST /export_pdf`: Handles asynchronous document print rendering and telemetry routing.
* `POST /open_terminal`: Spawns a dedicated console session for a repository or tool directory.
* `GET /status`: Health check, active PID, uptime, and request counters.

### 7.3 Compliance Checklist for Future Components
Any new table, viewer, or dashboard created in LCM must satisfy:
1. **No Silent Failures**: All user action clicks must either succeed via Port 9876 or display a graceful modal prompt informing the user to start `LcmDesktopDaemon.ps1`.
2. **Channel Parity**: Use the shared asset atoms (`LCM_Inventory/assets/lcm-table-print-atom.js`, `LCM_Inventory/assets/lcm-table-core.js`) rather than re-inventing table print, filtering, or IPC routines.
3. **Structured Telemetry**: Every call through Port 9876 must log a structured record in `LCM_Inventory/tools/logs/LcmDesktopDaemon-*.log`.

---

## 8. Methodology Reference Anchors

| Principle | Authoritative Specification | Primary Enforcement Tool / Hook |
|:---|:---|:---|
| **DOX Invariant** | [`AGENTS.md`](file:///D:/Git_Repositories/AGENTS.md), [`CM_POLICIES.md`](file:///D:/Git_Repositories/LCM_Inventory/docs/CM_POLICIES.md) | `LCM_Inventory/tools/Sync-GeminiInbox.ps1` |
| **Ledger Invariant** | `LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md` | `.gitignore`, `logs/cm_activity.log`, `data/reviews/` |
| **Review Gate Separation** | [`ProposalReviewFlowPolicy.md`](file:///D:/Git_Repositories/LCM_Inventory/.agents/rules/ProposalReviewFlowPolicy.md) | `LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1` |
| **Approach 1 Governance** | `LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md` | `LCM_Inventory/.agents/`, root `.gitignore` |
| **Snapshot Push Pipeline** | [`ReviewCommitGovernancePolicy.md`](file:///D:/Git_Repositories/LCM_Inventory/.agents/rules/ReviewCommitGovernancePolicy.md) | `LCM_Inventory/tools/Invoke-WorkspacePush.ps1` |
| **Port 9876 REST Bridge** | `CRP-2026-021`, `CM_POLICIES.md` | `LCM_Inventory/tools/LcmDesktopDaemon.ps1` |
