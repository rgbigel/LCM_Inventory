---
name: ReviewCommitGovernancePolicy
description: Authoritative governance policy for Review-Gated Commits, Acceptance with Edits, and Forced Commit Overrides.
globs: "*"
---
# File: ReviewCommitGovernancePolicy.md

Module: ReviewCommitGovernancePolicy  
Purpose: Defines mandatory review-gated commit rules, review disposition handling, forced commit overrides, audit logging, and dual-session directory junction reviews.  
Path: .agents/rules/ReviewCommitGovernancePolicy.md  
Authors: Rolf, Workspace_AI Governance  
Version: 7.1.0  
Status: Authoritative Policy  
Date: 2026-09-04  

---

## 1. Governance Rules

### RULE-REV-001: Mandatory Review-Gated Commits & Gate 2 Non-Circumvention Invariant
1. **Mandatory Visual Review Gate (Gate 2)**: Every Git commit action for source code, configuration, tools, modules, or structural assets (`*.ps1`, `*.psm1`, `.vscode/settings.json`, `.lcm/*`, `docs/*`) in any LCM-governed repository requires a prior validated review disposition (`ACCEPTED` or `ACCEPTED_WITH_EDITS`) produced via the formal Beyond Compare 5 visual review gate (`Invoke-BeyondCompareReview.ps1`).
2. **Strict Gate 2 Non-Circumvention for All Items**:
   - **Even critical, urgent, or internally generated BUGs MUST NOT circumvent Gate 2.**
   - While `BUG` items execute in `DOIT` mode (`always-proceed = $true`) without a Gate 1 planning pause, they `MUST HALT` at Gate 2 for operator review before reaching `COMMITTED`.
3. **Conversational Directives Do Not Waive Gating**: Explicit user instructions in chat (e.g. "yes, remove that", "fix this error") grant authority to execute file edits and staging, but **DO NOT waive the Beyond Compare visual review gate**. The agent `MUST` launch `Invoke-BeyondCompareReview.ps1` and await user review sign-off / folder clearance before stepping to `COMMITTED`.
4. **Exemption Scope**: Only purely mechanical telemetry artifacts defined in `RULE-EFF-001` (`inventory.json`, `INVENTORY_DASHBOARD.md`, `out/test_results.json`, and activity logs) are exempt from visual review gating.
5. **Non-Interactive / Headless Environment Fallback**: If Beyond Compare 5 or Session 1 interactive GUI execution is physically unavailable (e.g. running inside a headless CI/CD runner, container, or non-GUI remote SSH terminal), the agent `SHALL` present unified console diffs alongside the proposal's `Walkthrough.md` verification evidence for explicit terminal disposition before committing.

### RULE-REV-002: Accepted with Edits Qualification
When a review outcome is recorded as `Accepted with Edits` (or `Accepted with Change`):
1. The modified codebase `MUST` execute and satisfy all repository quality gates (`Test-RepoReadiness.ps1`).
2. The modifications `MUST NOT` introduce rule violations, regression errors, or broken dependencies.
3. Upon satisfying all quality gates, the state `SHALL` be classified as fully `ACCEPTED` and committed to Git.

### RULE-REV-003: Override & Force Authority for Rejected/Deferred States
If a review outcome is `REJECTED` or `DEFERRED`:
1. Automated commit and push pipelines `MUST` halt immediately.
2. Committing or pushing changes in a rejected or deferred state `IS FORBIDDEN` unless explicitly commanded by the user with a forced override instruction (e.g., `-Force` parameter or unambiguous explicit override prompt).

### RULE-REV-004: Precedence Over General Permission Rules
The review-gating rules (`RULE-REV-001` through `RULE-REV-003`) take strict precedence over any general "all commands are permitted" or automated background execution policies in effect across the workspace.

### RULE-REV-005: Universal Audit & Change Request Traceability
Every review disposition (`Accepted`, `AcceptedWithEdits`, `Rejected`, `Deferred`) `MUST` be recorded with an immutable timestamp, reviewer identity, repository HEAD SHA, and notes into:
1. `Workspace_Inventory/logs/cm_activity.log` (Append-only CM audit ledger).
2. `Workspace_Inventory/data/reviews/REVIEW-<Repo>-<Timestamp>.json` (Structured review evidence).
3. The active Change Request (CR) record in `Workspace_Inventory/data/change_requests.json` and mirrored proposal Markdown files when modifying governed baselines.

### RULE-REV-006: Mandatory Review Stop & Lifecycle Step Invariant
1. **Mandatory Review Stop**: Whenever an agent carries out a CRP or code modification reaching the visual review stage (Gate 2), the agent `MUST` launch `Invoke-BeyondCompareReview.ps1` and **immediately terminate the current response turn without making additional tool calls**.
2. **`Proceed` at Gate 2**: Upon operator submission of **`Proceed`** (or `Proceed <ID>`) after review inspection:
   - The proposal advances by exactly one status pulse: `REVIEW` $\rightarrow$ **`COMMITTED`**.
   - The local Git commit is created with the required SemVer increment per `RULE-REV-007`.
3. **`ACCEPT` / `ACCEPT ALL` (Push Trigger)**:
   - The `ACCEPT` command serves as an authoritative alias to **`PUSH`**.
   - `ACCEPT ALL` pushes **all currently `COMMITTED` proposals only** to remote repositories (`COMMITTED` $\rightarrow$ `PUSHED`).
   - Uncommitted proposals remain strictly in their local state.
   - Enforces the Push Auto-Reset Invariant: both `LCM Mode` and `Testing Mode` unconditionally revert to `ON`.

### RULE-REV-007: Mandatory Automatic Semantic Version Increment per Change Invariant
1. **Universal Version Increment Invariant**: Every change, proposal, or bug fix committed to any LCM-governed repository `MUST` increment that repository's semantic version before or during review commit:
   - **Patch Increment (`+0.0.1`)**: Standard default for all bug fixes, refinements, single-purpose enhancements, and incremental proposal completions.
   - **Minor Increment (`+0.1.0`)**: For substantive new feature sets, new tools, new sub-frameworks, or major multi-component proposals.
   - **Major Increment (`+1.0.0`)**: For global platform architectural transitions, governed by `RULE-DOC-005`.
2. **Synchronized Artifact Updates**:
   - The incremented version `MUST` be updated in:
     - DOX metadata headers of modified scripts and modules (`Version: M.Y.Z`).
     - Tripartite specifications (`Architecture.md`, `Requirements.md`, `Implementation.md`).
     - Top-level `README.md` and repository manifests.
     - `Workspace_Inventory/data/inventory.json` repository record.
   - Commit messages and review receipts `MUST` record the resulting semantic version (e.g. `feat(cm): ... [v7.1.1]`).
3. **Workspace_Inventory Operational Data Exemption**:
   - Routine data accounting mutations within `Workspace_Inventory` (specifically `data/inventory.json`, `data/proposals/proposals.json`, `logs/cm_activity.log`, `docs/INVENTORY_DASHBOARD.md`, and `data/reviews/*`) occurring as a standard byproduct of reviews, audits, proposal lifecycle transitions, or push recording `SHALL NOT` increment `Workspace_Inventory`'s semantic version.
   - Semantic version increments for `Workspace_Inventory` apply strictly when source code (`tools/*.ps1`, `modules/*.psm1`), specifications (`docs/*.md`), or governance policies are modified.

### RULE-REV-008: Dual-Session Beyond Compare Review for Reparse Points & Directory Junctions (.agents)
1. **Mandatory Dual-Session Review**: Whenever `Invoke-BeyondCompareReview.ps1` (or `BCR`) is executed against any repository containing NTFS directory junctions (specifically `.agents` pointing to `.lcm\.agents`, or `.agents\rules` pointing to `.lcm\.agents\rules`), the review tool `MUST` automatically detect the junction and dispatch a second Beyond Compare review session.
2. **Junction Session Layout**:
   - **Left Pane (Baseline Snapshot)**: The extracted Git baseline directory corresponding to the junction (e.g. `<TempReviewRoot>\.agents` or `<TempReviewRoot>\.agents\rules`). If the directory does not exist in the baseline snapshot, the tool `MUST` initialize it.
   - **Right Pane (Live Junction Target)**: The resolved live junction destination on disk (e.g. `D:\Git_Repositories\.lcm\.agents` or `D:\Git_Repositories\.lcm\.agents\rules`).
3. **Session Persistence**: The second comparison `MUST` be registered in `BCSessions.xml` under `LCM_Review_<JunctionName>` and launched to Session 1 desktop via the interactive desktop dispatcher.
4. **Staging & Review Directives**: All review actions (Accept, Edit, Delete, Defer) applied in the second session `MUST` be tracked and integrated into the review audit manifest (`staged_review_<Repo>.json`).
