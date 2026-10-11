# Configuration Management (CM) Policies & Invariants

Module: docs/CM_POLICIES.md
Purpose: Formal rules, policies, and invariants governing Configuration Management across the multi-repo workspace.
Path: D:\Git_Repositories\LCM_Inventory\docs\CM_POLICIES.md
Authors: Rolf, LCM_AI Engine
Version: 2.0.0
Date: 2026-08-30

---

## 1. Scope & Authority

This document defines the binding Configuration Management (CM) invariants for all repositories and directories located under `D:\Git_Repositories\`.

1. **CM Authority**: `LCM_Inventory` is the authoritative CM catalog, auditing authority, and proposals ledger repository.
2. **LCM Governance Authority**: Canonical governance rules reside in `.agents/rules/` and are inherited across all child repositories via NTFS directory junctions.
3. **Repository Autonomy**: Component repositories own their source code, tests, and target-local tripartite documentation (`Architecture.md`, `Requirements.md`, `Implementation.md`, `install/Installation.md`).

---

## 2. Repository Classification Policy

Every directory under `D:\Git_Repositories\` must have an explicit classification:

* **`lcm-governed`**: A software repository onboarded into LCM, possessing valid directory junctions to `.agents/rules/`, root agent instructions, and tripartite documentation.
* **`active-design-workshop`**: Incubation workshops for development (`LCM_AI`, `LCM_Inventory`).
* **`standard-git`**: A Git repository currently un-onboarded to LCM.
* **`non-git`**: A component directory lacking a `.git` database, listed in `git.ignoredRepositories`.
* **`legacy-retired`**: Off-limits historical reference repositories.
* **`parent-infra`**: Root Solution workspace infrastructure directories (`.agents`, `.copilot`, `.github`, `.venv`, `.vscode`, `.lcd`).

---

## 3. Two-Tier Proposal & Progress State Lifecycle

Every workspace proposal in `LCM_Inventory/data/proposals/proposals.json` operates under an authoritative two-tier lifecycle model:

### 3.1 Plan State (Governance Intent)
* `bug`: Raw intake error / issue feedback below suggested. Can be promoted to `suggested` or `approved`.
* `suggested`: Proposed change awaiting operator review.
* `approved`: Formally approved; queued for AI agent implementation.
* `deferred`: Postponed to a future release milestone.
* `rejected`: Dropped or cancelled.
* `completed`: Formally reviewed, accepted, and committed in Git.

### 3.2 Progress State (Execution Status)
* `undecided`: Initial unstarted state.
* `queued`: Approved by operator, placed in execution queue awaiting AI agent implementation.
* `in_progress`: Active implementation / agent development.
* `verification`: Implementation complete; awaiting Beyond Compare visual review.
* `completed`: Review accepted and dual-commit sync complete.
* `blocked`: Execution prevented by external system/environment dependencies.
* `failed`: Automated quality gate failed or implementation crashed.

---

## 4. Beyond Compare 5 Visual Review Gate & Scratch Baseline

1. **Variant A Scratch Baseline**: Baseline inspection trees are hosted strictly under `LCM_Inventory/scratch/BC_Review/<CRP>_<Repo>_<CommitSha>`. User-profile AppData directories must **never** be used for workspace review baseline storage.
2. **Review Directives**:
   * **Copy Right to Left**: Staged for acceptance upon operator disposition.
   * **Line 'Delete' on Left**: Permanently deletes file on disk and in Git.
   * **Line 'Rename to X' on Left**: Renames file on disk and in Git.
   * **Leave Left Untouched**: Skipped / uncommitted in working tree.
3. **Completion Gating**: Only proposals in `verification`, `in_progress`, or `approved` state are eligible for `COMPLETE` / `COMPLETE ALL`. Items in `undecided`, `deferred`, `blocked`, or `rejected` are strictly blocked from completion.

---

## 5. Audit, Activity Logging & History Retention Policy

1. **Structured Activity Ledger**: Commit, push, review acceptance, and onboarding events must append a structured record to `logs/cm_activity.log` containing:
   `[Timestamp] [Status] [Target: <Repo>] [Version: <Version>] [PushDate: <PushDate>] [AffectedRepos: <Repos>] <Action> - <Details>`
2. **History Archive Horizon ($M-2$)**: Historical activity is preserved permanently in `logs/history/` across major version boundaries ($\ge 2$ major versions retained).

3. **Recovery Lifecycle Records**: The current lifecycle is a flat
   `state`/`state_reason` pair. Existing history is immutable; later events
   append richer records rather than rewriting old entries.
4. **Temporary CRP Absorption**: CRP bundles are active specifications. Push
   absorbs delivered behavior into baseline documentation. A revision reopens
   the same ID in `suggested` and records a forward-only revision event.
5. **Semantic Delta Restart**: A semantic active-specification change restarts
   only affected CRPs and requires review/testing only for the declared delta.
   Cohort coordination bundles may record shared scope and verification.

---

## 6. CM Control Hub Web Application (`Show-CmControlHub`)

The **LCM Configuration Management Control Hub** (`docs/CM_CONTROL_HUB.html`) provides the authoritative visual mission control interface:

1. **Launchers & Trampolines**:
   * `pwsh tools/Show-CmControlHub.ps1`
   * `CmHub.cmd` (Full Dashboard)
   * `DOR.cmd` / `DoReview.cmd` (Review Mode)
2. **Key Capabilities**:
   * **Multi-Facet Header Filters**: Filter by Scope, Plan State, or Progress State (defaulting to `Open / Non-Completed`).
   * **Batch Operations**: Multi-select Beyond Compare review, batch gated acceptance, one-shot mark reviewed, and batch defer/delete.
   * **Notepad++ Integration**: Open specifications in Notepad++ via Desktop REST Daemon (`POST /open_editor`) with automated plan sync upon save.
   * **Repository Tripartite Documentation Review**: Built-in subpanel to inspect and compare `Architecture.md`, `Requirements.md`, `Implementation.md`, `install/Installation.md`, and `README.md`.
   * **Push & Synchronization Engine**: 1-click `🚀 Push / Sync Repos` with custom or default CRP reason prompts.
   * **Print-Ready Documents**: Export/print plans, walkthroughs, and specs to PDF with `@media print` typography.
   * **Docked Interactive Console**: Bottom terminal feed for real-time CLI command execution and operator status feedback.
   * **State Navigation**: `ShowCM` is both overview and requested
     state-navigation surface, including accept/reject and repository, cohort,
     and complete forms.

The BCR surface remains the principal visual review mechanism. Generated
artifacts, scratch content, data, logs, and routine test output require no
review, but may be inspected through an explicitly unfiltered BCR peek and may
produce helpful non-blocking advice. Managed lifecycle hooks remain retained
for governed transitions.

---

## 7. Canonical Governance Tracking Architecture (Approach 1)

1. **Physical Tracking Anchor**: Version control tracks canonical governance rules, hook configurations, and session context strictly under the physical directory `LCM_Inventory/.agents/`.
2. **NTFS Directory Junction Exemption**: Root container junction `/.agents/` is excluded in root `.gitignore` to prevent Windows NTFS reparse point collision and duplicate index tracking.
3. **Single Source of Truth**: Sibling and child repositories link `.agents/rules/` to `LCM_Inventory\.agents\rules` via NTFS directory junctions. Modifying rules in any child updates the canonical physical store immediately.

---

## 8. The Ledger Invariant: Audit Logs as Permanent Memory

1. **Logs Constitute the Ledger**: Historical and active audit logs (`LCM_Inventory/data/logs/lcm/*.log`, `LCM_Inventory/tools/logs/*.log`, `LCM_Inventory/logs/cm_activity.log`, and `data/reviews/*.json`) are immutable evidence records of system activity and are never exempt from Git tracking.
2. **Snapshot Invariant**: Root `.gitignore` must allow-list `LCM_Inventory/data/logs/lcm/` so that complete historical causality and execution receipts are committed and preserved across disaster recovery.
3. **Exempt Runtime Data**: Only purely regenerable transient data (compiled scratchpad HTML in `LCM_Inventory/scratch/`, `.tmp` buffers, and lock files) is excluded from version control.

---

## 9. Restorable Snapshot Push & Pre-Push Pipeline

1. **Snapshot Guarantee**: Every push dispatched via `Invoke-WorkspacePush.ps1` must represent an immutable, 100% restorable disaster-recovery baseline.
2. **Pre-Push Sequence**:
   * **Gemini Rules Mirroring (`RULE-LCM-013`)**: Consolidates 17 rules to `LCM_AI/docs/LCM_Rules_Gemini_Export.md` and mirrors to `D:\GDrive\LCM`.
   * **Catalog Snapshot**: Recompiles and commits `tool_catalog.json` and command trampolines before push dispatch.
   * **Dry-Run Simulation**: Supports `-DryRun` (`-WhatIf`) to inspect queued commits, affected repositories, and proposal transitions prior to remote execution.
   * **Post-Push Finalization**: Transitions completed proposals to `pushed` in `data/proposals/proposals.json` and appends `PUSH_EXECUTED` to `logs/cm_activity.log`.

---

## 10. Browser Display Table Communication Standard (Port 9876 Channel Compliance)

1. **Universal Channel Compliance**: All browser-rendered display tables, viewers, and tool explorers across the workspace must route interactive host commands (tool execution, file opening, document printing/export) exclusively through the localhost Port 9876 REST Bridge Daemon (`http://127.0.0.1:9876/`).
2. **Prohibition of Direct Sandbox Egress**: Client-side JavaScript running in web views or browsers must never attempt direct OS execution or silent fallback popups. If the daemon is unreachable, the UI must prompt the user to start `LcmDesktopDaemon.ps1`.
3. **Shared Asset Reuse**: Display tables must utilize the shared LCM atom modules (`LCM_Inventory/assets/lcm-table-print-atom.js`, `LCM_Inventory/assets/lcm-table-core.js`) to guarantee uniform behavior and telemetry logging.

See authoritative methodology specification in [`docs/LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md`](file:///D:/Git_Repositories/LCM_Inventory/docs/LCM_METHODOLOGY_AND_MEMORY_ANCHOR.md).
