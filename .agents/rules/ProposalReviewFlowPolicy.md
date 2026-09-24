---
name: ProposalReviewFlowPolicy
description: Governs the LCM Two-Tier Proposal lifecycle, ticket-first enforcement, batch operations, granularity controls, and dual-commit synchronization.
globs: "*"
---
# File: ProposalReviewFlowPolicy.md

Module: ProposalReviewFlowPolicy  
Purpose: Enforces ticket-first proposals, batch commands, Beyond Compare 5 review gates, granularity controls, and Workspace_Inventory dual-commit synchronization.  
Path: .agents/rules/ProposalReviewFlowPolicy.md  
Authors: Rolf, Workspace_AI Governance  
Version: 7.6.0  
Status: Authoritative Policy  
Date: 2026-09-20  

---

## 1. Core LCM Review Flow Rules

### RULE-LCM-001: Proposal-First Intent Invariant
When working in LCM mode (`active`), all user ideas, questions, and exploratory discussions `MUST` be treated as **Proposals only** (State = `suggested`).
- The AI agent `MUST NOT` execute file modifications, code rewrites, or commits immediately upon receiving an initial idea or question.
- When discussion yields a conclusive path of action, register the Change Request / Proposal with State `suggested` in `Workspace_Inventory\data\proposals\proposals.json`.

### RULE-LCM-002: Batch Execution & Control Commands
Proposals transition through the defined lifecycle via deterministic operator commands:
- **`Proceed` / `Proceed <ID>`**: **Single-step status increment**. Deterministically advances matching proposal(s) forward by exactly one discrete state:
  - At Gate 1: Advances from `SUGGESTED` $\rightarrow$ `IN_PROGRESS` (initiates implementation in Normal Cycle).
  - At Gate 2: Advances from `REVIEW` $\rightarrow$ `COMMITTED` (satisfies visual review, records disposition, increments SemVer, and commits to local Git).
- **`do <all, #n, #n-#m> Proposals`**: **Activates `DOIT` mode** (`always-proceed = $true`). Bypasses Gate 1 planning pauses and executes planned tool operations, script runs, and file edits continuously until downstream Gate 2 is reached per `RULE-EFF-004`.
- **`ACCEPT` / `ACCEPT ALL`**: **Alias to PUSH**. Pushes **all currently `COMMITTED` proposals only** to remote repositories (`COMMITTED` $\rightarrow$ `PUSHED`) in lockstep, enforcing the remote push version synchronization per `RULE-REV-007`. Uncommitted, suggested, or in-review items are strictly excluded from push.
- **`delete <all, #n, #n-#m> Proposals`**: Sets matching proposals to `deleted` and clears associated CRs.
- **`defer <all, #n, #n-#m> Proposals`**: Sets matching proposals to `deferred`.
- **`give open Proposals`**: Returns numbered list of active proposals (`#n`).
- **`give repos under review`**: Displays repositories with uncommitted changes, their BC5 review status, and commit readiness.

### RULE-LCM-003: Review Granularity Controls
The review frequency is governed by `review_granularity` in `Workspace_Inventory`:
- **`coarse` (Default)**: Executes all proposals in the batch, runs automated quality gates, then presents a **single BC5 review stop** for the combined changes across the repository before commit.
- **`tight`**: Implements each proposal incrementally with intermediate test runs and a **dedicated BC5 review stop per proposal**.
- Can be set via `set review granularity <coarse|tight>` or inline `do #1-#3 Proposals --tight`.

### RULE-LCM-004: Visual Diff Review & Exemption Scope
- **Governed Repositories & Root Container**: Every governed repository and the Root Container (`D:\Git_Repositories`) `MUST` undergo visual diff review via `Invoke-BeyondCompareReview.ps1 <RepoName>` before commit.
- **Dual-Session Junction Review**: For repositories containing NTFS directory junctions (e.g. `.agents` pointing to `.lcm\.agents`, or `.agents\rules` pointing to `.lcm\.agents\rules`), `Invoke-BeyondCompareReview.ps1` `MUST` automatically dispatch a second Beyond Compare review session targeting the live junction destination on the right pane per `RULE-REV-008`.
- **Privileged Subsystem Data Exemption vs. Tool Scrutiny**:
  - **Dynamic Configuration & Ledger Data Exemption (`RULE-EFF-001`)**: Ledger data, review staging receipts, baseline manifests, telemetry logs, and scratch generation outputs located in `Workspace_Inventory` (`data/`, `logs/`, `scratch/`) are auto-accepted mechanical evidence and exempt from visual diff review stops.
  - **Executable Tools & Documentation Scrutiny**: All permanent scripts, PowerShell modules, test suites, and architectural documentation located in `Workspace_Inventory` (`tools/`, `modules/`, `docs/`, `tests/`, `Cmd/`) are first-class governed LCM software assets and `MUST` undergo visual diff review via `Invoke-BeyondCompareReview.ps1 Workspace_Inventory` prior to commit.

### RULE-LCM-005: Dual-Commit and Push Synchronization Invariant
1. Whenever code changes in a target repository are accepted and committed, `Workspace_Inventory` `MUST ALWAYS` be updated (updating proposal state to `completed`, recording review evidence) and **committed immediately**.
2. On any `git push` (`ACCEPT ALL`), all modified target repositories and `Workspace_Inventory` `MUST` be pushed to their respective remotes in lockstep.

### RULE-LCM-006: Pause, Resume, and Escape Controls
1. **`LCM OFF` (Emergency Escape Switch)**:
   - Temporarily suspends proposal bundle scaffolding and governance gating to enable immediate emergency remediation of corrupted host configurations or broken environments.
   - Re-activated via `LCM ON` or `resume LCM`.
2. **`Testing OFF` (Deferred Deep Testing Switch)**:
   - Suppresses heavy, multi-minute test cascades (deep Pester DAGs, elevated integration test suites) during rapid interactive development and intermediate Gate 2 checkpoints.
   - Syntax validation and fast unit checks still run, but deep testing is strictly deferred to the pre-push quality gate.
   - **Deferred Failure Protocol**: If deep testing encounters errors during pre-push validation, the push is immediately aborted and the failure automatically spawns a formal **`BUG`** proposal bundle in `DOIT` mode (`RULE-LCM-008`).
3. **Push Auto-Reset Invariant (Self-Healing Governance)**:
   - Neither `LCM OFF` nor `Testing OFF` may remain active after publication. Upon any push invocation (`ACCEPT`, `ACCEPT ALL`, `Invoke-WorkspacePush.ps1`), both **LCM Mode** and **Testing Mode** `MUST` unconditionally reset to `ON` (`active`).

### RULE-LCM-007: Dual-State Proposal Lifecycle & CM Plan Archive Invariant
1. **Dual-State Separation**: Every proposal in `Workspace_Inventory/data/proposals/proposals.json` `MUST` track both:
   - **Governance Plan State (`state`)**: Document approval state (`bug`, `suggested`, `approved`, `deferred`, `rejected`, `completed`, `pushed`).
   - **Implementation Progress State (`progress_state`)**: Physical execution progress (`undecided`, `queued`, `in_progress`, `verification`, `completed`, `pushed`, `blocked`, `failed`).
2. **Initial Invariant**: Every newly submitted proposal and unapproved plan `MUST` initialize with `progress_state: "undecided"`.
3. **Pushed Lifecycle Transition**: Upon successful execution of `Invoke-WorkspacePush.ps1` (or CM Control Hub Push), proposals in `completed` state whose origin repository was pushed `MUST` transition to `pushed` (`pushed_at` timestamp recorded).
4. **Mandatory CM Plan & Walkthrough Archival**:
   - All Markdown implementation plans and execution walkthroughs `MUST` be persistently archived in the governed CM repository under:
     - `Workspace_Inventory/data/proposals/plans/Proposal-{ID:03d}_{CR_ID}_Plan.md`
     - `Workspace_Inventory/data/proposals/plans/Proposal-{ID:03d}_{CR_ID}_Walkthrough.md`
   - Explicit relative links `plan_path` and `walkthrough_path` `MUST` be recorded in `proposals.json`.

### RULE-LCM-008: BUG Lifecycle, DOIT Mode & Gate 2 Non-Circumvention Invariant
1. **Birth in `DOIT` Mode**: When a `BUG` is born (whether reported by the operator or self-discovered during test execution), it automatically initializes in **`DOIT` Mode** (`always-proceed = $true`).
   - The agent scaffolds the BUG proposal bundle (`docs/Proposals/BUG-<nnn>-[Slug]/`) and immediately executes code modifications, script adjustments, and unit verification tests continuously without pausing for a Gate 1 planning approval.
2. **Strict Gate 2 Non-Circumvention Invariant**:
   - **Even a critical, urgent, or internally generated BUG MUST NOT circumvent Gate 2.**
   - Once the fix is verified in the working tree and logged in `Walkthrough.md`, the agent `MUST UNCONDITIONALLY HALT` at Gate 2, dispatch the visual review session (`Invoke-BeyondCompareReview.ps1`), and await explicit operator review disposition. The agent `MUST NEVER` self-commit or self-push bug fixes.

### RULE-LCM-009: Scope and Version-Explicit CRP Naming Standard
1. **Canonical Directory Bundle Convention**: All Change Request Proposals (CRPs) `MUST` follow the standardized bundle directory structure:
   `docs/Proposals/CRP-<nnn>-[Slug]/` containing `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
   - `nnn`: Universal monotonic sequence integer zero-padded to at least 3 digits (e.g. `018`, `119`), matching the proposal ledger `id` 1:1.
   - `[Slug]`: Descriptive kebab-case intent description.
2. **Mandatory Header Metadata**: Every CRP specification `MUST` include explicit metadata fields:
   - `Target Scope`: Explicit repository or subsystem boundary.
   - `Affected Version Range`: Semantic version or range.
   - `Impacted Repositories`: Array of modified repositories.
3. **Legacy Flat File Fallback**: Historical CRPs (e.g. `CRP-001` through `CRP-017`) authored as flat `.md` files remain valid and governed under `RULE-LCM-020` Mode 3 (Legacy Fallback).

### RULE-LCM-010: Mandatory Self-Discovered Bug Registration Invariant
1. **Mandatory Self-Discovery Reporting**: Whenever the AI agent discovers a bug, syntax defect, unhandled runtime exception, parser failure, or regression in a permanent tool, platform script, shared module, or web UI during development, testing, or tool execution (including deferred deep testing failures per `RULE-LCM-006`), the AI agent `MUST` formally register a Bug Report in `Workspace_Inventory/data/proposals/proposals.json` and scaffold the accompanying proposal bundle.
2. **Immediate Remediation in `DOIT` Mode**: The self-discovered bug transitions directly into `DOIT` mode to diagnose and resolve the failure, but remains bound by the Gate 2 Non-Circumvention Invariant (`RULE-LCM-008`).
3. **Prohibition of Silent In-Place Hotfixing**: The AI agent `MUST NOT` silently patch defects in permanent tools without registering a formal BUG entry in the Configuration Management ledger.

### RULE-LCM-011: Scope and Version-Explicit Bug Report Naming Standard
1. **Canonical Bug Bundle Directory Convention**: All formal Bug Reports `MUST` follow the standardized bundle structure:
   `docs/Proposals/BUG-<nnn>-[Slug]/` containing `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
   - `nnn`: Universal monotonic sequence integer zero-padded to at least 3 digits (e.g. `024`, `092`), sharing the exact same sequence counter as CRPs and matching the proposal ledger `id` 1:1.
2. **Mandatory Frontmatter Metadata**: Every Bug Report `MUST` include explicit frontmatter fields:
   - `Bug-ID`: Sequential unique identifier sharing the sequence counter with CRPs (e.g. `BUG-024`, `BUG-092`).
   - `Scope`: Affected repository or subsystem boundary.
   - `Version`: Target release baseline (e.g. `v7.1.0`).
   - `Affected-Repos`: Array of modified repositories.
   - `Severity`: Impact assessment (`Low`, `Medium`, `High`, `Critical`).
   - `Status`: Lifecycle status (`Open`, `In-Progress`, `Completed`).
   - `Root-Cause`: Concise explanation of failure mechanics.
3. **Legacy Flat File Fallback**: Historical Bug Reports (e.g. `BUG-024` through `BUG-094`) authored as flat `.md` files remain valid and governed under `RULE-LCM-020` Mode 3 (Legacy Fallback).

### RULE-LCM-012: Mandatory Scope-and-Version Explicit CRP Specification Generation Invariant
1. **Mandatory Standalone Specification**: Whenever proposing, designing, or implementing new features, tools, workflows, architectural enhancements, or governance policies, the AI agent `MUST` author a formal, standalone Scope-and-Version Explicit Change Request Proposal specification (`Specification.md`) within its proposal bundle in `Workspace_Inventory/docs/Proposals/` before or alongside ledger registration.
2. **Prohibition of Orphan Feature Proposals**: Proposing or executing features or tool modifications without an authoritative, permanent proposal bundle in `Workspace_Inventory/docs/Proposals/` is strictly prohibited. Every non-bug feature proposal in `proposals.json` `MUST` link to a valid `bundle_id` matching an existing CRP bundle.

### RULE-LCM-013: Mandatory Pre-Push Gemini AI & Knowledge Base Synchronization Invariant
1. **Mandatory Automated Pre-Push Execution**: Every push operation executed via `Invoke-WorkspacePush.ps1` (or `ACCEPT ALL` triggers), whether multi-repository or targeting a single repository (`-Repositories <repo>`), `MUST` automatically execute the `Update-Gemini.ps1` pipeline prior to pushing commits to remote Git repositories. Direct manual `git push` invocations that bypass `Invoke-WorkspacePush.ps1` are prohibited.
2. **Context & Rules Mirroring Parity**: This guarantees that all 17 canonical LCM rules (`Workspace_AI/docs/LCM_Rules_Gemini_Export.md`), plain-text `.txt` mirrors, tool catalogs, and full workspace knowledge base exports (`D:\GDrive\LCM`) are 100% synchronized with the pushed Git baseline at the moment of remote dispatch.
3. **Automated Export Commit**: If the `Update-Gemini` pipeline updates the consolidated rules export in `Workspace_AI`, those changes `MUST` be staged and committed immediately before dispatching the push to `origin/main`.

### RULE-LCM-014: Dual-Gate Architecture & CRP Planning Gate Invariant
1. **CRP Birth in SUGGESTED State**: For any non-bug Change Request Proposal (`CRP`), the proposal `MUST` birth in the **`SUGGESTED`** state under the Normal Review Cycle.
2. **Gate 1 Planning Halt**: The AI agent `MUST` scaffold the Proposal Bundle directory, register the entry in `proposals.json`, present the plan, and `UNCONDITIONALLY HALT`. No source code, permanent script, configuration, or test file may be modified, created, or deleted while at Gate 1.
3. **Gate 1 Activation Triggers**:
   - **`Proceed`**: Advances state from `SUGGESTED` $\rightarrow$ `IN_PROGRESS` in the Normal Review Cycle (interactive checkpoints if open questions or design alternatives exist).
   - **`do` / `do <ID>`**: Advances state to `IN_PROGRESS` and activates **`DOIT` Mode** (`always-proceed = $true`), executing planned modifications continuously until Gate 2 is reached per `RULE-EFF-004`.
4. **Strict Dual-Gate Lifecycle**:
   - **Gate 1 (Planning Gate)**: Propose solution / Register proposal bundle & plan $\rightarrow$ `STOP` and await explicit operator direction (`Proceed` or `do`). (BUGs bypass Gate 1 into `DOIT` mode).
   - **Gate 2 (Review Gate / BC5 Gate)**: Implement approved changes $\rightarrow$ Present visual diffs / walkthrough / BC5 review $\rightarrow$ `STOP` and await operator review disposition. **Mandatory for all proposals, including BUGs.**

### RULE-LCM-015: Strict Intake Classification Gate
1. **Intake Signal Classification**:
   - `CRP:` designator indicates a Change Request Proposal: enters `SUGGESTED` state and halts at Gate 1.
   - `BUG:` designator indicates a Defect Report: enters `DOIT` mode immediately and executes directly to Gate 2.
2. **Priority Ordering**: Priority markings (including "*highest priority*" or "*critical*") affect execution order in batch queues; they `DO NOT` authorize bypassing Gate 2 visual review.

### RULE-LCM-016: Deterministic Lifecycle Command Invariants
1. **`Proceed` / `Proceed <ID>`**:
   - Deterministic single-status pulse: advances the target proposal forward by exactly **one discrete state**.
   - Gate 1: `SUGGESTED` $\rightarrow$ `IN_PROGRESS`.
   - Gate 2: `REVIEW` $\rightarrow$ `COMMITTED` (satisfies review, records audit disposition, increments SemVer, and commits to local Git).
2. **`do <ID>` / `do <batch>`**:
   - Activates **`DOIT` Mode** (`always-proceed = $true`), running all planned tool operations continuously from Gate 1 to Gate 2.
3. **`ACCEPT` / `ACCEPT ALL`**:
   - Authoritative alias to **`PUSH`**.
   - Filters and pushes **all currently `COMMITTED` proposals only** to remote repositories (`COMMITTED` $\rightarrow$ `PUSHED`).
   - Uncommitted, suggested, or in-review items remain strictly in their local state and are never pushed.
   - Enforces the Push Auto-Reset Invariant (`RULE-LCM-006`): resets `LCM Mode` and `Testing Mode` to `ON`.iew.

### RULE-LCM-017: Autonomous System Exception Boundary & 2-Attempt Loop Breaker
1. **Autonomous Exception Scope**: As a sole exception to `RULE-LCM-016`, the AI agent is permitted to assume an implicit `PROCEED` to immediately remediate a self-discovered or runtime-generated `BUG` `ONLY IF` all of the following conditions are simultaneously met:
   - **Critical System/Transport Behavior**: The defect represents a severe runtime blocker directly disrupting operations (e.g., REST daemon socket drops on Port 9876, IPC transport failures, or blocking background daemon aborts).
   - **Within Agent Capability**: The root cause is definitively identified and remediable within the agent's direct operational scope.
   - **No Architectural Redesign**: The fix requires no architectural redesign, schema changes, or breaking API alterations.
   - **Net Positive Impact**: The fix will not create cascading side-effects or regressions exceeding the problem being solved.
2. **Mandatory 2-Attempt Loop Breaker**:
   - If two (2) consecutive attempts to fix the runtime defect fail to resolve the issue, the autonomous `PROCEED` exception is **immediately and irrevocably revoked**.
   - The agent `MUST HALT` all modification attempts, mark the BUG item as `blocked`/`open` in the ledger, document the failure telemetry, and yield full control back to the operator.

### RULE-LCM-018: Credit Exhaustion & Batch Execution Granularity Guard
1. **Batch Size Safety**: Multi-item batches `MUST` be segmented into manageable, verifiable increments to prevent credit, context, and token exhaustion.
2. **Discrete Review Boundaries**: Each approved proposal or tight batch `MUST` reach a stable, verifiable state before proceeding to subsequent items, guaranteeing that uncommitted or partially modified code never leaves the workspace in an unrecoverable state.

### RULE-LCM-019: Active App Context Inheritance & Automated Tripartite Synthesis on ACCEPT
1. **Active Context Inheritance (`Workon:`)**:
   - When an active App context is set via `Workon: A<#>` (e.g. `Workon: A1`), all subsequent Change Request Proposals (`crp: ...`), Bug Reports (`bug: ...`), and tasks generated during this focus `MUST` automatically inherit the active `app_id` (e.g. `"App: 1"`) in `proposals.json`.
   - When set to `Workon: Architecture` or cleared (`Workon: Base`), proposals are recorded with `app_id: $null` (foundational system scope).
2. **Automated Tripartite Synthesis upon `ACCEPT`**:
   - The `ACCEPT <id>` / `complete <id>` command serves as the authoritative lifecycle trigger that concludes an App increment.
   - Upon `ACCEPT`, the conclusive architecture decisions, technical requirements, and code manifests associated with the proposal `MUST` be synthesized into the repository's tripartite documentation under the designated `App: #` section:
     - Architectural summary $\rightarrow$ `Architecture.md` under `## App: #`
     - Normative invariants $\rightarrow$ `Requirements.md` under `## App: #`
     - Manifest table $\rightarrow$ `Implementation.md` under `## App: #`
3. **Multi-App Problem Resolution Gating**:
   - For multi-App bugs (`BUG-###`), the proposal `MUST` explicitly declare `primary_app` (root cause) and `affected_apps` (blast radius).
   - The bug cannot be marked `completed` or `committed` until the unit tests of the primary App *and* the integration tests of all affected Apps pass 100%.
   - On `ACCEPT`, documentation updates are synthesized across all affected App sections in a single atomic step.

### RULE-LCM-020: Proposal Bundle Directory Architecture, Dual Lifecycle & Git Object Document Retrieval
1. **Self-Contained Proposal Directory Bundles**:
   - Every proposal across the workspace (whether LCM core or child repository feature) `MUST` be stored in a dedicated proposal bundle directory:
     `docs/Proposals/CRP-<nnn>-[Slug]/` (or `BUG-<nnn>-[Slug]/`).
   - Each proposal bundle directory `MUST` contain three standardized Markdown documents:
     - `Specification.md` (Domain intent, problem statement, requirements, architectural tradeoffs, and metadata header)
     - `Implementation_Plan.md` (Technical file diff breakdown, component plans, and verification strategy)
     - `Walkthrough.md` (Execution receipts, test execution logs, before/after evidence, and operational verification)
2. **Pre-Push Working Tree Lifecycle**:
   - During proposal authoring, implementation planning, active coding, and review gating, the proposal bundle directory lives in the local repository working tree and is directly queryable by developers, CLI tools, and the CM Control Hub.
3. **Post-Push Working Tree Purge Invariant**:
   - Upon `Invoke-WorkspacePush.ps1` (or push workflow execution):
     - The target repository head commit SHA `MUST` be captured and recorded in `proposals.json` (`commit_sha: "<SHA>"`).
     - The remote GitHub tree link `MUST` be generated and recorded (`github_url: "<URL>"`).
     - The completed local proposal bundle directory `MUST` be purged from the working tree, ensuring 0 dead or redundant proposal directories remain in the working tree.
4. **Dual-Mode Document Retrieval Protocol (`Get-LcmProposalDocument`)**:
   - Tools, scripts, and dashboards `MUST` resolve proposal documents using the dual-mode resolution protocol:
     - **Mode 1 (Live Disk)**: If the bundle directory exists on disk (`Test-Path`), read content directly from the working tree.
     - **Mode 2 (Git Object Extraction)**: If the local directory has been purged, extract document content directly from the local repository Git object store using `git -C <RepoPath> show "<commit_sha>:<bundle_dir>/<file>"`.
     - **Mode 3 (Legacy Fallback)**: For pre-CRP-162 historic proposals, fall back to flat `plan_path` and `walkthrough_path` targets.

