# Configuration Management (CM) Policies & Invariants

Module: docs/CM_POLICIES.md
Purpose: Formal rules, policies, and invariants governing Configuration Management across the multi-repo workspace.
Path: D:\Git_Repositories\Workspace_Inventory\docs\CM_POLICIES.md
Authors: Rolf, Workspace_AI Engine
Version: 2.0.0
Date: 2026-08-30

---

## 1. Scope & Authority

This document defines the binding Configuration Management (CM) invariants for all repositories and directories located under `D:\Git_Repositories\`.

1. **CM Authority**: `Workspace_Inventory` is the authoritative CM catalog, auditing authority, and proposals ledger repository.
2. **LCM Governance Authority**: Canonical governance rules reside in `.agents/rules/` and are inherited across all child repositories via NTFS directory junctions.
3. **Repository Autonomy**: Component repositories own their source code, tests, and target-local tripartite documentation (`Architecture.md`, `Requirements.md`, `Implementation.md`, `install/Installation.md`).

---

## 2. Repository Classification Policy

Every directory under `D:\Git_Repositories\` must have an explicit classification:

* **`lcm-governed`**: A software repository onboarded into LCM, possessing valid directory junctions to `.agents/rules/`, root agent instructions, and tripartite documentation.
* **`active-design-workshop`**: Incubation workshops for development (`Workspace_AI`, `Workspace_Inventory`).
* **`standard-git`**: A Git repository currently un-onboarded to LCM.
* **`non-git`**: A component directory lacking a `.git` database, listed in `git.ignoredRepositories`.
* **`legacy-retired`**: Off-limits historical reference repositories.
* **`parent-infra`**: Root Solution workspace infrastructure directories (`.agents`, `.copilot`, `.github`, `.venv`, `.vscode`, `.lcd`).

---

## 3. Two-Tier Proposal & Progress State Lifecycle

Every workspace proposal in `Workspace_Inventory/data/proposals/proposals.json` operates under an authoritative two-tier lifecycle model:

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

1. **Variant A Scratch Baseline**: Baseline inspection trees are hosted strictly under `Workspace_Inventory/scratch/BC_Review/<CRP>_<Repo>_<CommitSha>`. User-profile AppData directories must **never** be used for workspace review baseline storage.
2. **Review Directives**:
   * **Copy Right to Left**: Staged for acceptance upon operator disposition.
   * **Line 'Delete' on Left**: Permanently deletes file on disk and in Git.
   * **Line 'Rename to X' on Left**: Renames file on disk and in Git.
   * **Leave Left Untouched**: Skipped / uncommitted in working tree.
3. **Acceptance Gating**: Only proposals in `verification`, `in_progress`, or `approved` state are eligible for `ACCEPT` / `ACCEPT SELECTED`. Items in `undecided`, `deferred`, `blocked`, or `rejected` are strictly blocked from acceptance.

---

## 5. Audit, Activity Logging & History Retention Policy

1. **Structured Activity Ledger**: Commit, push, review acceptance, and onboarding events must append a structured record to `logs/cm_activity.log` containing:
   `[Timestamp] [Status] [Target: <Repo>] [Version: <Version>] [PushDate: <PushDate>] [AffectedRepos: <Repos>] <Action> - <Details>`
2. **History Archive Horizon ($M-2$)**: Historical activity is preserved permanently in `logs/history/` across major version boundaries ($\ge 2$ major versions retained).

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
