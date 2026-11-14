# Implementation Plan: CRP-331

Module: docs/Proposals/CRP-331-Claude-Reingestion-Rule-Harmonization-Findings/Implementation_Plan.md  
Purpose: Structured, phased implementation plan for resolving all findings from Claude's re-ingestion of canonical LCM rules at baseline 2bebbaa.  
Path: LCM_Inventory/docs/Proposals/CRP-331-Claude-Reingestion-Rule-Harmonization-Findings/Implementation_Plan.md  
Authors: Rolf, Antigravity & Claude  
Version: 10.6.4  
Status: In Progress  
Date: 2026-11-14 21:18:00  

---

## 1. Overview & Phasing Architecture

To guarantee single authorship, zero accidental regressions, and rigorous verification, implementation is partitioned into three disjunct batches:

- **Batch 1: Core Contradictions & Data Store Authority** (Completed)
  - `F-18`: Major SemVer arithmetic alignment (`+1.0.0` resets lower digits for all parts).
  - `F-19`: Language-specific indentation rules in `GoRules.md` (tabs) & `PythonRules.md` (4 spaces).
  - `F-20`: Migration of lifecycle vocabulary to authoritative flat state table (`suggested`, `in_progress`, `verified`, `in_review`, `completed`, `pushed`, `held`, `withdrawn`, `rejected`, `superseded`).
  - `F-21`: Review tool and baseline model alignment (unifying references to `BCR.cmd` / `Invoke-MacriumBcrReview.ps1` with `<FollowSymLinks Value="True"/>`).
  - `F-22`: Removal of phantom `LCM_Inventory/config.json` references; citation of true data sources.
  - `F-42` / `F-46`: Clarification of SQLite `proposals.db` and `tools.db` authority over transitional JSON files.
  - `F-47`: Re-labeling "Cause no havoc" from "Non-Goal" to "Binding Invariant / Principle" of every Gate 0 Contract.

- **Batch 2: Tooling References, Dead Scripts & Invariant Hygiene** (Completed)
  - `F-21 (Residual)`: Reconciled baseline model between `RULE-REV-008.3` (fallback BaseCommit) and `RULE-REV-014` (primary mounted Macrium root baseline).
  - `F-23`: DoT (`LCM_Inventory\DoT\do.exe`) established as single dispatch route; obsolete runners retired (`Invoke-PrivilegedTool.ps1`, `Invoke-InteractiveDesktop.ps1`).
  - `F-24`: `data/tools/tools.db` codified as catalog authority; JSON catalog as transitional fallback.
  - `F-25`: Retired non-existent `Invoke-LCMUpdate.ps1` from `MethodEfficiencyPolicy.md`.
  - `F-27`: Plan archive path (`data/proposals/plans/`) retired; bundle architecture (`RULE-LCM-020`) codified.
  - `F-28`: Unified default review granularity to `tight` across `ProposalReviewFlowPolicy.md` and `DecisionCascadeGovernancePolicy.md`.
  - `F-33`: Header normalization and macro authority synchronization; `@tsr` retired.
  - `F-34`: Frontmatter globs aligned with `RULE-AUTH-004` tiers.
  - `F-40`: Protected operator-owned Beyond Compare windows in `RULE-DSP-008.5`.
  - `F-41`: Normalized `"state": "completed"` and `"test_scope": "minimal"` across `RULE-DEC-004.2` and `RULE-DEC-005.2`.
  - `F-42`: Corrected CRP-326 implementation record with reconciliation section 6.3.
  - `F-48`: Codified repository elevation declaration source in `AGENTS.md` aggregated via `Invoke-LCM_Audit.ps1` into `inventory.json`.
  - `F-49`: Synchronized `Date: 2026-11-14` headers across all 21 canonical rule files.

- **Batch 3: Host-Neutral Session Continuity Architecture** (Completed)
  - Joint schema and protocols for GoodNight / GoodMorning across Antigravity and Claude (`RULE-LCM-030`, `Section 9`).
  - Standardized multi-host session registry in `.agents/ACTIVE_SESSION.md` (`SC-2`).
  - Cross-host attention items aggregation and quiescence synchronization (`SC-3`, `SC-4`, `RULE-CTX-006`).
  - Multi-host learned advice collaboration, attribution, and lifecycle (`SC-6`, `SC-7`, `RULE-CTX-005`, `RULE-LCM-031`).
  - Host-native memory pointers invariant and disk authority (`RULE-AUTH-001.5`).
  - Full DOX header normalization on `GoRules.md` (`F-37`), enabling 21/21 rule files verification in `Invoke-LCM_GoodMorning.ps1`.

---

## 2. Batch 1 Proposed Steps

### Step 1: Major Version Arithmetic (F-18)
- In `LCM_AI/.agents/rules/DocumentationStandardsPolicy.md` (`RULE-DOC-005`):
  - Replace preservation examples with standard reset semantics: Major version increments (`+1.0.0`) reset minor and patch digits to 0 for all parts (`10.2.5` $\to$ `11.0.0`).

### Step 2: Language Indentation Rules (F-19)
- In `LCM_AI/.agents/rules/GoRules.md`:
  - Codify explicit indentation rule: standard Go formatting uses hard tabs via `gofmt`.
- In `LCM_AI/.agents/rules/PythonRules.md`:
  - Codify explicit indentation rule: standard Python formatting uses 4 spaces per PEP 8.

### Step 3: Lifecycle Vocabulary Alignment (F-20)
- In `LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md`:
  - Align lines 124, 128-130, 170, 186, 205, 343 to use authoritative flat states: `suggested`, `in_progress`, `verified`, `in_review`, `completed`, `pushed`, `held`, `withdrawn`, `rejected`, `superseded`.
  - Relegate 7 Sync Points to historical lineage reference.
  - Standardize lifecycle verbs: `withdraw` (retiring `cancel`), `continue` (retiring `resume`).
- In `LCM_AI/.agents/rules/ReviewCommitGovernancePolicy.md`:
  - Update `RULE-REV-001.2` and `RULE-REV-006` (`in_review` $\to$ `completed` instead of `REVIEW -> COMMITTED`).
- In `LCM_AI/.agents/rules/DisplayStandardsPolicy.md`:
  - Update `RULE-DSP-003.3` and `RULE-DSP-011` status rail / timeline to use the flat state table.

### Step 4: Review Tool & Baseline Model Alignment (F-21)
- In `LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md` (`RULE-LCM-004`, `RULE-LCM-008`), `ReviewCommitGovernancePolicy.md` (`RULE-REV-001`, `RULE-REV-006`, `RULE-REV-008`), `MethodEfficiencyPolicy.md` (`RULE-EFF-004`), and `macro-definitions.md`:
  - Remove all references to non-existent `Invoke-BeyondCompareReview.ps1`.
  - Unify review entry point to `BCR` / `BCR.cmd` / `Invoke-MacriumBcrReview.ps1` with transparent single-window junction traversal (`<FollowSymLinks Value="True"/>`).

### Step 5: Removal of `LCM_Inventory/config.json` (F-22)
- Across `LCM_AI/.agents/rules/`:
  - `RepositoryContextPolicy.md` (`RULE-CTX-002`): Remove `LCM_Inventory/config.json`. Cite common governance in rules and subsystem-specific facts in `docs/`.
  - `ElevationPolicy.md` (`RULE-ELEV-001`, `003`, `004`): Remove `config.json`. Point to `tools.admin` in `data/tools/tools.db` and `inventory.json` (`ElevationRequired`, `MinimumPrivilege`).
  - `SubsystemGovernancePolicy.md` (`RULE-SUB-001`, `003`): Remove `config.json`.
  - `DocumentationStandardsPolicy.md` (`RULE-DOC-005.4`): Remove `config.json`.

### Step 6: Data Store Authority (F-42 / F-46)
- In `LCM_AI/.agents/rules/ProposalReviewFlowPolicy.md` and `ReviewCommitGovernancePolicy.md`:
  - Replace references to `proposals.json` as sole authority with SQLite `proposals.db` accessed via governed tools (`Update-Proposal.ps1`, `Invoke-ProposalAction.ps1`, `Sync-LcmProposalsDb.ps1`).
  - Clarify that JSON files are transitional fallbacks.

### Step 7: "Cause No Havoc" Invariant Label (F-47)
- In `LCM_AI/.agents/rules/GoalFirstDesignPolicy.md` (`RULE-GOAL-002`) and `DocumentationStandardsPolicy.md` (`RULE-DOC-003.1`):
  - Re-label "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity" as a binding core invariant/principle of every Gate 0 Contract.

---

## 3. Verification Plan
- Execute `Test-GeneralReadiness.ps1` across `LCM_AI` and `LCM_Inventory` verifying clean UTF-8 No-BOM, AST syntax, and all 7 gates.
- Verify that `Assert-LcmPackageVersion` passes cleanly.
- Verify Control Hub compiles and displays updated data without errors.
