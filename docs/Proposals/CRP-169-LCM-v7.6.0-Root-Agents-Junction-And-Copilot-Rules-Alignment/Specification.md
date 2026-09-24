# Change Request Proposal: CRP-169

```yaml
CRP-ID: CRP-169
Title: Deploy Root .agents Junction, Reconcile Command Taxonomy, and Align .copilot Rules
Scope: Multiple
Affected-Scopes:
  - D:\Git_Repositories
  - D:\Git_Repositories\.copilot
  - Workspace_Inventory
  - Workspace_AI
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-24 17:40:00
Status: In_Progress
Plan-State: approved
Progress-State: in_progress
Priority: High
App-ID: Architecture
```

---

## 1. Executive Summary & Intent

This proposal addresses three core architectural requirements across workspace governance:
1. **Broken Root Discovery Junction**: The root workspace container `D:\Git_Repositories` does not contain an `.agents` directory or junction. While `.lcm\.agents\rules` correctly links to `Workspace_Inventory\.agents\rules`, agents and IDE sessions rooted at `D:\Git_Repositories` fail to discover `.agents/rules`, `ACTIVE_CONTEXT.md`, and `ACTIVE_SESSION.md`.
2. **Command Taxonomy & Lifecycle Reconciliation**: Reconciles the conflicting terms between `RULE-LCM-014` and `RULE-EFF-004` by establishing a strict Finite State Machine:
   - Clean separation of the **Normal Review Cycle** from **`DOIT` Mode** (`always-proceed`).
   - Redefining **`Proceed`** as a deterministic single-status step forward across all gates (`SUGGESTED` $\rightarrow$ `IN_PROGRESS` at Gate 1; `REVIEW` $\rightarrow$ `COMMITTED` at Gate 2).
   - Redefining **`do`** as the explicit trigger for `DOIT` mode.
   - Redefining **`ACCEPT` / `ACCEPT ALL`** as an alias to `PUSH`, pushing `COMMITTED` proposals only and triggering semantic version increment.
   - Strict BUG Invariant: BUGs birth in `DOIT` mode, but **MUST NOT** circumvent Gate 2 review.
   - Escape mechanisms: `LCM OFF` (emergency bypass) and `Testing OFF` (deferred deep testing to pre-push, where pre-push failures automatically spawn formal BUG proposals).
   - Auto-Reset Invariant: Upon push, both `LCM` and `Testing` unconditionally reset to `ON`.
3. **Outdated `.copilot` Rules Repository**: The tracked directory `D:\Git_Repositories\.copilot\Rules` contains only 8 stale rule files dating to July 2026. This proposal synchronizes all 17 canonical rules into `.copilot/Rules/` and `.copilot/` root.

---

## 2. Requirements & Problem Statement

### Requirement 1: Deploy Root `.agents` Directory Junction
- Deploy an NTFS directory junction at `D:\Git_Repositories\.agents` targeting `D:\Git_Repositories\.lcm\.agents`.
- Ensure `D:\Git_Repositories\.agents\rules` immediately resolves the 17 authoritative policy files in `Workspace_Inventory\.agents\rules`.
- Ensure `.agents/ACTIVE_CONTEXT.md` and `.agents/ACTIVE_SESSION.md` resolve cleanly at root.
- Validate that `D:\Git_Repositories\.gitignore` excludes `/.agents/` and `/.agents` to prevent Git tracking churn.

### Requirement 2: Command Taxonomy & Governance Reconciliation
- **State Machine Definition**:
  - `CRP` Birth: Always starts in `SUGGESTED` state (Normal Review Cycle, Gate 1 planning pause).
  - `BUG` Birth: Always starts in `DOIT` mode (`always-proceed = $true`, direct execution to Gate 2).
  - **Gate 2 Non-Circumvention**: Even critical, internally generated BUGs must halt at Gate 2 (diff / BC5 review) before commit.
- **Operator Commands**:
  - `Proceed`: Single-status pulse (`SUGGESTED` $\rightarrow$ `IN_PROGRESS`; `REVIEW` $\rightarrow$ `COMMITTED`).
  - `do`: Starts `DOIT` mode (`always-proceed` continuously to Gate 2).
  - `ACCEPT`: Alias to `PUSH` for the target proposal.
  - `ACCEPT ALL`: Pushes all `COMMITTED` proposals only, triggering SemVer increment.
- **Escape Switches & Self-Healing Defaults**:
  - `LCM OFF`: Emergency bypass switch.
  - `Testing OFF`: Skips deep testing during iteration, deferring it to pre-push.
  - Pre-Push Regression Protocol: Any failure during pre-push deep testing blocks push and automatically spawns a formal `BUG` proposal in `DOIT` mode.
  - Auto-Reset Invariant: At push, both `LCM` and `Testing` unconditionally revert to `ON`.

### Requirement 3: Align `.copilot` Rules and Eliminate Root Duplicates
- Synchronize all 17 canonical rule files from `Workspace_Inventory\.agents\rules` into `D:\Git_Repositories\.copilot\Rules\`.
- Remove legacy duplicate files from `.copilot/` root (`InvariantRules.md`, `macro-definitions.md`) to establish `.copilot/Rules/` as the single authoritative rule location.
- Update `.copilot/Config.json` durable memory paths to reference `Rules/InvariantRules.md` and `Rules/macro-definitions.md`.
- Verify cryptographic SHA256 hash parity across all 17 rules in `Rules/`.
