# Specification: CRP-326

## Document Information
- **Proposal ID**: `CRP-326`
- **Title**: Governance Rules Harmonization, Lifecycle Consistency, and Authoritative Version Alignment
- **Author**: Rolf & Antigravity (LCM Governance)
- **Status**: Open / Draft (Awaiting Claude Amendment & Gate 1 Operator Review)
- **Date**: 2026-11-13
- **Target Repository**: `LCM_AI`, `LCM_Inventory`, Multi-Repository Workspace
- **Impacted Subsystems**: `.agents/rules/`, `AGENTS.md`, `.agents/version.json`, `LCM_Inventory/data/proposals/`
- **Scope Restriction**: Documentation and Governance Rules only (zero production code changes in this phase)

---

## 1. Executive Summary & Problem Statement

A comprehensive audit of the LCM multi-repository governance rules, cross-reference matrix, and operational ledgers conducted across AI IDEs (Claude and Antigravity) identified multiple critical contradictions, historical drift, corrupted examples, and missing rule codifications. 

These inconsistencies create ambiguity for AI agents operating under LCM governance. This CRP establishes a consolidated inventory of all identified governance defects and defines the exact corrections required to achieve 100% harmonization across rules, matrices, and metadata ledgers without modifying production application code.

---

## 2. Decision Logged (Operator Instruction)

### Authoritative LCM Version Specification
- **Action**: Create [`.agents/version.json`](file:///d:/Git_Repositories/.agents/version.json) as the sole machine-readable authority for the active LCM version.
- **Current Baseline SemVer**: `10.2.5`
- **Format**:
  ```json
  {
    "version": "10.2.5",
    "updated_at": "2026-11-13"
  }
  ```
- **Harmonization Target**: Synchronize `10.2.5` into `LCM_Inventory/data/inventory.json` (`GlobalLCMVersion` and child repos), root [AGENTS.md](file:///d:/Git_Repositories/AGENTS.md) DOX header, and [.agents/ACTIVE_CONTEXT.md](file:///d:/Git_Repositories/.agents/ACTIVE_CONTEXT.md).

---

## 3. Inventory of Confirmed Rule Contradictions & Corrections (Batch 1)

### Item 1: `RULE-CTX-006` vs `LEARNED_ADVICE` vs `ACTIVE_CONTEXT` (GoodMorning Session Start)
- **Defect**: 
  - `RepositoryContextPolicy.md` (`RULE-CTX-006`) states the AI agent *MUST* execute `Invoke-LCM_GoodMorning.ps1 -Auto` at session start.
  - `LEARNED_ADVICE.md` (accepted 2026-11-09) explicitly establishes operator exclusivity: GoodMorning is only run by the operator, never by the AI as an envelope to obtain a baseline or perform multi-repo research.
  - `ACTIVE_CONTEXT.md` references a non-existent script name `Invoke-WorkspaceGoodMorning.ps1` instead of `Invoke-LCM_GoodMorning.ps1`.
- **Planned Correction**:
  - Update `RULE-CTX-006` in `RepositoryContextPolicy.md` to reflect accepted learned advice: GoodMorning is an operator-executed tool; the AI's role at session start is purely read-only verification of attention items/flags already recorded in context files.
  - Correct the script reference in `ACTIVE_CONTEXT.md` to `LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1`.

### Item 2: Corrupted SemVer Increments (`+10.0.0`) in `RULE-REV-007` and `RULE-DOC-005`
- **Defect**:
  - `ReviewCommitGovernancePolicy.md` (`RULE-REV-007`) lists `+10.0.0` as the increment offset for Patch, Minor, and Major alike due to an aggressive historical find-and-replace defect.
  - `DocumentationStandardsPolicy.md` (`RULE-DOC-005`) contains corrupted illustrative examples (e.g. `e.g. 10.0.0, 10.0.0` and `version 10.0.0 when major version 7 is established becomes 10.0.0`).
- **Planned Correction**:
  - Restore the proper standard SemVer increment offsets in `RULE-REV-007`:
    - Patch: `+0.0.1`
    - Minor: `+0.1.0`
    - Major: `+1.0.0`
  - Correct the illustrative transformation examples in `RULE-DOC-005`.

### Item 3: `RULE-LCM-004` (Dual-Session Review) vs `RULE-REV-008` (Retired Dual Sessions)
- **Defect**:
  - `ProposalReviewFlowPolicy.md` (`RULE-LCM-004`) states that for junctions, Beyond Compare *MUST* dispatch a second review session targeting the live junction destination.
  - `ReviewCommitGovernancePolicy.md` (`RULE-REV-008`) explicitly declares that dual-session Beyond Compare review dispatch is retired in favor of transparent junction traversal (`<FollowSymLinks Value="True"/>`).
- **Planned Correction**:
  - Harmonize `RULE-LCM-004` with `RULE-REV-008` by eliminating the dual-session dispatch mandate and codifying transparent single-window junction traversal.

### Item 4: Lifecycle Vocabularies & Transition Divergence
- **Defect**:
  - `ProposalReviewFlowPolicy.md` contains conflicting lifecycle paradigms: the CRP-261 compatibility note declares the flat state table authoritative and demotes terms like `Scoped` and `Decided`, yet `RULE-LCM-007` still defines the 7-stage sync continuum (`Suggested` $\rightarrow$ `Scoped` $\rightarrow$ `Decided` $\rightarrow$ `In_Progress` $\rightarrow$ `Verified` $\rightarrow$ `Committed` $\rightarrow$ `Published`).
  - Meanwhile, `RULE-LCM-016` defines `Proceed` as jumping `SUGGESTED` $\rightarrow$ `IN_PROGRESS` and `REVIEW` $\rightarrow$ `COMMITTED`, conflicting with the 7-step sequence.
- **Planned Correction**:
  - Reconcile `RULE-LCM-007` and `RULE-LCM-016` to strictly reflect the authoritative flat state continuum (`suggested`, `in_progress`, `in_review`, `completed`, `pushed` / `held`, `cancelled`), demoting the 7 sync points to historical lineage reference.

### Item 5: Ledger Authority Ambiguity (`proposals.json` vs `proposals.db`)
- **Defect**:
  - Canonical rules mandate writing directly to `LCM_Inventory/data/proposals/proposals.json`.
  - `LEARNED_ADVICE.md` (2026-11-13) specifies that `proposals.db` is the authoritative store, with `proposals.json` to be eliminated once tooling is validated.
  - AI agents lack guidance on how to interact with the ledger during this transitional coexistence.
- **Planned Correction**:
  - Document the transition protocol: agents must invoke canonical synchronization tools (`Sync-LcmProposalsDb.ps1`, `Update-Proposal.ps1`) rather than making ad-hoc manual writes, until the formal retirement milestone of `proposals.json` is completed.

### Item 6: Rule File Counting Inconsistencies & Stray Typo
- **Defect**:
  - `RULE-LCM-013` cites "all 17 canonical LCM rules".
  - `AGENTS.md` Section 2 states "18 authoritative rule files".
  - The actual physical count in `.agents/rules/` is 21 files.
  - `ProposalReviewFlowPolicy.md` line 333 contains a stray editing artifact: `resets 'LCM Mode' and 'Testing Mode' to 'ON'.iew.`.
- **Planned Correction**:
  - Replace brittle hardcoded file counts with dynamic references or update to the true count (21 files).
  - Remove the trailing `.iew.` typo on line 333 of `ProposalReviewFlowPolicy.md`.

---

## 4. Inventory of Structural Rule Issues (Batch 2)

### Item 7: Duplicate `RULE-DOC-008` in `DocumentationStandardsPolicy.md`
- **Defect**:
  - Line 65: `### RULE-DOC-008: Goal-First Proposal Contract`
  - Line 140: `### RULE-DOC-008: Specification Preservation Invariant`
  - Line 140 is the authoritative `RULE-DOC-008` recognized in the cross-reference matrix; Line 65 duplicates content covered by `GoalFirstDesignPolicy.md` (`RULE-GOAL-001` - `005`).
- **Planned Correction**:
  - Retain Line 140 as the sole authoritative `RULE-DOC-008` (Specification Preservation Invariant).
  - Replace Line 65 with a pointer referencing `GoalFirstDesignPolicy.md`.

### Item 8: Missing `RULE-PS-025` in `PowerShellStandardsPolicy.md`
- **Defect**:
  - `AGENTS.md`, `LCM-Rules-Cross-Reference.md`, and `CRP-310` all cite `RULE-PS-025: Model-Atom-Controller (MAC) Modular Implementation Invariant`.
  - Accepted learned advice from 2026-11-09 defines the MAC architecture.
  - However, `PowerShellStandardsPolicy.md` ends at `RULE-PS-024`; `RULE-PS-025` was never codified into the file.
- **Planned Correction**:
  - Draft and append `RULE-PS-025` into `PowerShellStandardsPolicy.md` defining the MAC modular architecture (modular atom externalization, code segment bounding, and mandatory Pester test coverage).

---

## 5. Scope for Upcoming Claude Amendments

*(This section is reserved for Claude to append newly identified findings, loose recommendations, and the remaining operator decision points before review gating.)*

