# Implementation Plan: CRP-169

```yaml
CRP-ID: CRP-169
Title: Deploy Root .agents Junction, Reconcile Command Taxonomy, and Align .copilot Rules
Scope: Multiple
Baseline-Version: v7.6.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-24 17:40:00
Status: In_Progress
```

---

## 1. Planned Changes Breakdown

### Phase 1: Establish Root NTFS Directory Junction
- Execute command:
  ```cmd
  cmd /c mklink /J "D:\Git_Repositories\.agents" "D:\Git_Repositories\LCM_Inventory\.agents"
  ```
- Verify junction resolution:
  - `Test-Path "D:\Git_Repositories\.agents\rules\RuleAuthority.md"` $\rightarrow$ `True`
  - `Test-Path "D:\Git_Repositories\.agents\ACTIVE_CONTEXT.md"` $\rightarrow$ `True`
  - `Test-Path "D:\Git_Repositories\.agents\ACTIVE_SESSION.md"` $\rightarrow$ `True`

### Phase 2: Codify Command Taxonomy & Governance Reconciliation
- In `LCM_Inventory\.agents\rules\ProposalReviewFlowPolicy.md`:
  - Update `RULE-LCM-002` and `RULE-LCM-016`:
    - `Proceed` = Single-step status pulse (`SUGGESTED` $\rightarrow$ `IN_PROGRESS` or `REVIEW` $\rightarrow$ `COMMITTED`).
    - `do` = Activation trigger for `DOIT` mode (`always-proceed` continuously to Gate 2).
    - `ACCEPT` / `ACCEPT ALL` = Alias to `PUSH`, pushing `COMMITTED` proposals only, triggering SemVer increment.
  - Update `RULE-LCM-006`: Add `LCM OFF` (emergency bypass) and `Testing OFF` (deferred deep testing). Codify auto-reset to `ON` at push.
  - Update `RULE-LCM-008` & `RULE-LCM-010`: Codify BUG birth in `DOIT` mode with Gate 2 non-circumvention invariant.
  - Update `RULE-LCM-014`: Focus on Gate 1 for CRPs (`SUGGESTED` state birth), referencing `DOIT` mode for execution velocity.
- In `LCM_Inventory\.agents\rules\MethodEfficiencyPolicy.md`:
  - Update `RULE-EFF-004`: Define the **`DOIT` Mode Standard** (`always-proceed`) as active by default on BUGs and active on CRPs when triggered via `do`.
- In `LCM_Inventory\.agents\rules\ReviewCommitGovernancePolicy.md`:
  - Update `RULE-REV-001`, `006`, `007`: Reconcile Gate 2 as the mandatory universal barrier before `COMMITTED`, and bind `ACCEPT` / `ACCEPT ALL` to push `COMMITTED` proposals with SemVer increment.

### Phase 3: Synchronize Canonical Rules to `.copilot/Rules\` & Consolidate Root
- Source: `D:\Git_Repositories\LCM_Inventory\.agents\rules\` (17 authoritative policy files).
- Destination: `D:\Git_Repositories\.copilot\Rules\`
  - Copy all 17 rule files into `D:\Git_Repositories\.copilot\Rules\`.
- Consolidate & Eliminate Root Duplicates:
  - Remove legacy duplicate files `D:\Git_Repositories\.copilot\InvariantRules.md` and `macro-definitions.md`.
  - Update `.copilot/Config.json` durable memory paths to reference `Rules/InvariantRules.md` and `Rules/macro-definitions.md`.

### Phase 4: Verification & Operational Receipts
- Execute automated verification script:
  - Validate count of rule files in `.copilot\Rules\` equals 17.
  - Compute SHA256 hashes of all files in `.copilot\Rules\` vs `LCM_Inventory\.agents\rules\` to prove 100% cryptographic parity.
  - Verify junction attributes on `D:\Git_Repositories\.agents`.
  - Populate `Walkthrough.md`.
  - Present Gate 2 Review to operator.
