# Specification: CRP-326

## Document Information
- **Proposal ID**: `CRP-326`
- **Title**: Governance Rules Harmonization, Lifecycle Consistency, and Authoritative Version Alignment
- **Author**: Rolf & Antigravity (LCM Governance)
- **Status**: Completed (Gate 2 Accepted by Operator)
- **Date**: 2026-11-14
- **Target Repository**: `LCM_AI`, `LCM_Inventory`, Multi-Repository Workspace
- **Impacted Subsystems**: `.agents/rules/`, `AGENTS.md`, `.agents/version.json`, `LCM_Inventory/data/proposals/`
- **Scope Restriction**: Documentation and Governance Rules only (zero production code changes in this phase)

```yaml
CRP-ID: CRP-326
Title: Governance Rules Harmonization, Lifecycle Consistency, and Authoritative Version Alignment
Scope: LCM_AI
Baseline-Version: 10.6.4
Author: Claude, Rolf & Antigravity
Date: 2026-11-13 21:28:31
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 9
App-ID: None
```

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

> Amended by Claude (Anthropic), 2026-11-13 21:39:39. Rule baseline: `LCM_AI` `43e36b0` (2026-11-12 18:30:41). Source register: `LCM_AI/.claude/translation/FINDINGS.md` (IDs `F-nn`). Mapping status: batch 1 of the rule files only (RuleAuthority, InvariantRules, LanguagePolicy, RepositoryContextPolicy, GoalFirstDesignPolicy); later batches will be appended here.

### 5.1 Finding Types

| Type | Meaning |
| :--- | :--- |
| `CONTRADICTION` | Two rules require incompatible things. |
| `IMPRECISE` | The rule cannot be applied without interpretation. |
| `GAP` | Missing provision, or the rule names something that does not exist. |
| `STALE` | Outdated literal (version, name, count). |
| `REDUNDANT` | Same obligation stated twice. |
| `HOST` | Mechanism that only one AI host can provide. |
| `HOST-CONTEXT` | Correct for Antigravity/Gemini; needs a host-specific reading, not a rule fix. |
| `OPEN-END` | Known unfinished area of the methodology; records what is missing, not an error. |

### 5.2 Amendments to Items 1-8

- **Item 1**: Agreed. The Claude mapping already treats `RULE-CTX-006` as pending; Claude does not run GoodMorning.
- **Item 2** (adds operator semantics, 2026-11-13): restoring `+0.0.1` / `+0.1.0` / `+1.0.0` is necessary but not sufficient. The corrected `RULE-REV-007` and `INVARIANT-RULES/single-commit-version-increment` should also state:
  - Version bump: `+1.0.0`, resetting minor and patch to `0` for ALL parts (e.g. `10.2.5` -> `11.0.0`).
  - Release: `+0.1.0`.
  - GoodNight push: `+0.0.1` only for components that really changed; unchanged components keep their patch digit.
  - "Clean" state is required at release only, not at GoodNight pushes.
  - Operator (2026-11-13, Q-06): a release does not change the patch digit at reset; the patch digit changes on completion (commit).
- **Item 4**: the target list (`suggested`, `in_progress`, `in_review`, `completed`, `pushed` / `held`, `cancelled`) differs from the state machine in `LCM_Inventory/docs/Implementation.md` section 4.1 and from the `proposals.state` CHECK constraint in `LCM_Inventory/docs/DataDesign-Proposals.md`, which both have `suggested`, `in_progress`, `verified`, `in_review`, `completed`, `pushed`, `held`, `withdrawn`, `rejected`, `superseded` and no `cancelled`. The correction should use that list.
- **Item 5**: the named tools exist (`Update-Proposal.ps1`, `Sync-LcmProposalsDb.ps1`, `sync_proposals_db.py`; checked 2026-11-13).

### 5.3 New Findings (Batch 1)

| ID | Rule | Type | Finding | Proposed correction |
| :--- | :--- | :--- | :--- | :--- |
| F-01 | `RULE-AUTH-001` | HOST-CONTEXT | "IDE adapter surfaces MUST NOT fork" leaves no legal form for a host adapter (e.g. `.claude/`) that must restate rules in another host's format. | Add an adapter clause: permitted when mapped from the canonical rules, citing source IDs and baseline commit, and drift-checked by a gate. |
| F-02 | `RULE-AUTH-002` | HOST-CONTEXT | Sync list names only `AGENTS.md` and `LCM-Rules-Cross-Reference.md`; host adapters (`CLAUDE.md`, `.claude/rules/`) go stale silently. | Add "all registered host adapters", produced by the planned rule-sync tool. |
| F-03 | `RULE-AUTH-002.3` | IMPRECISE | "Verify ... visible across all child junctions" names no method. | Name `LCM_Inventory/tools/Test-LCMRuleHealth.ps1` (exists). |
| F-04 | `INVARIANT-RULES/newline-crlf` | IMPRECISE | "Windows-native files" undefined (`*.go`, `*.py`, `*.sh`, `*.svg`, `*.sql`?). | Explicit extension list or "all text files except <list>". |
| F-05 | `INVARIANT-RULES/indent-2` | IMPRECISE | Universal 2 spaces, no tabs; Go (`gofmt`: tabs) and Python (PEP 8: 4 spaces) differ. To be confirmed against GoRules / PythonRules. | Let the language rule own indentation, or list exceptions. |
| F-06 | `INVARIANT-RULES/ascii-default` vs `LANGUAGE-POLICY-RULES/code-comments` | IMPRECISE | Umlauts allowed in PowerShell comments, but comments MUST be English; legitimate cases not stated. | Restrict to proper names, paths and data literals. |
| F-07 | `INVARIANT-RULES/mandatory-pre-handoff-syntax-gate` | OPEN-END | Lists `*.cmd` without a parser; omits `*.go`, `*.psd1`, `*.md`, `*.html`, `*.js`, `*.sql`, `*.yaml`. Operator: simple, needs docs. | Name a verification command per type (Go: `go vet` / `go build`; psd1: `Import-PowerShellDataFile`) or state "no gate". |
| F-08 | `INVARIANT-RULES/question-response` | IMPRECISE | The example of an instruction starts with a question; requests phrased as questions ("Can you fix X?", "Maybe you need to scan the docs first?") are unclassified. | Define: an imperative addressed to the AI is an instruction even inside a question; a request phrased only as a question is answered, then the AI asks whether to act. Operator to confirm. |
| F-09 | `INVARIANT-RULES/english-default-language` vs `LanguagePolicy`; `no-verbosity` vs `zero-conversational-padding` | REDUNDANT | Same obligations stated twice. | One owner each; references elsewhere. |
| F-10 | `RULE-CTX-002` (also `LCM-REQ-033`) | GAP | `<TargetRepo>/LCM_Inventory/config.json` exists in no repository (checked 2026-11-13); the rule cannot be followed. | State the current location of per-repository LCM configuration. |
| F-11 | `RULE-CTX-002` note | OPEN-END | `Invoke-LCMOnboardRepo.ps1` does not exist; operator: onboarding as a whole is an open end. | Mark onboarding "planned, not available" until designed. |
| F-12 | `RULE-CTX-004` | STALE | States baseline "(10.0.0)"; current 10.2.5. `LCM_Shared` described as PowerShell-only. | Reference `.agents/version.json` instead of a literal. |
| F-13 | `RULE-CTX-001` (1) | HOST | Active IDE document assumed always available; absent in headless runs. | State fallback order for hosts without IDE metadata. |
| F-14 | `RULE-GOAL-002` | IMPRECISE | "Structural, cross-cutting, materially ambiguous, scope-expanding" undefined; this is the planning-boundary trigger. Operator context: BUG = clear error, essentially no Gate 0; `DOIT` = target known, go quickly to Gate 2. | State the trigger by context: no Gate 0 pause for BUGs or under `DOIT`; pause only for a CRP in standard flow whose target state is not evident from title or request. |
| F-15 | `LanguagePolicy.md` | IMPRECISE | Header deviates (Antigravity banner, `Changelog:` instead of `Status:`/`Date:`), no `RULE-*` IDs. | Align header; introduce `RULE-LANG-001..005`. |
| F-16 | `INVARIANT-RULES/timestamp-header-rule` | HOST | Operator waived the header for Claude; rules have no host-exception provision. | Add a host-exception provision or record the waiver in `overrides.json`. |

F-17 (version increment semantics) is folded into Item 2 above.

### 5.4 Operator Decision Points

| ID | Question |
| :--- | :--- |
| Q-02 | Are Claude's built-in file search tools acceptable, or must discovery always use `es.exe` / `Search-Everything.ps1` (`RULE-EFF-007`)? |
| Q-03 | Resolved by Item 5 once accepted. |
| Q-04 | May Claude write to the shared `.agents/LEARNED_ADVICE.md` (`/learn`, `RULE-CTX-005`), or keep its learned advice separate until the rule sets are synchronized? |
| Q-05 | Where is the per-repository LCM configuration today (F-10)? |
| Q-06 | Answered: a release does not change the patch digit at reset; the patch digit changes on completion (commit). |
| Q-07 | Answered: a question-phrased request means the AI sees a need to answer with solution paths, with or without suggestions; it answers and does not act (resolves F-08). |

### 5.5 Observations on this Specification File

- No DOX header and no YAML metadata block (`CRP-ID`, `Status`, `Plan-State`, `Progress-State`), unlike e.g. CRP-320. `LCM_Inventory/docs/Implementation.md` section 4.1 says `ProposalSpecificationState.psm1` projects state changes into exactly those header fields. Not tested.
- The file uses LF line endings (`INVARIANT-RULES/newline-crlf`). Claude appended this section without converting the file, to keep the review diff limited to the amendment.

---

## 6. Gate 1 Acceptance & Harmonization Implementation Record

### 6.1 Operator Decisions (2026-11-14)
1. **Multi-Host Adapters Accepted**: Recognized host adapters are Antigravity, Claude Code, Gemini, VS Code, and Cursor (not just Claude/AGY). Derived adapters are authorized read-only projections of canonical rules.
2. **Language Rules & Deference**: Language-specific standards (`PowerShellStandardsPolicy.md` / `PowerShellRules.md`, `PythonRules.md`, `GoRules.md`, `CMDRules.md`, `JsonRules.md`, `DisplayStandardsPolicy.md`) take precedence over generic quality defaults (`quality/`); any language may have a dedicated rule file.
3. **Macro Waiver**: The standard datetime format (`YYYY-MM-DD HH:mm:ss[.fff]`) remains binding, but the `@tsr` macro is **permanently retired and dropped workspace-wide** due to VS Code changes.
4. **Tri-Tier Rule Architecture (`RULE-AUTH-004`)**: Canonical rules in `.agents/rules/` and derived projections are classified into:
   - **Process Governance (`process/`)** (10 files)
   - **Solution Quality & Invariants (`quality/`)** (4 files)
   - **Language-Specific Standards & Presentation (`lang/`)** (7 files)

### 6.2 Executed Implementation Ledger
- **Machine-Readable Baseline**: Created `LCM_AI/.agents/version.json` declaring SemVer `10.3.0`.
- **`RuleAuthority.md`**: Codified `RULE-AUTH-001`, `002`, `004` (Multi-Host adapter legitimacy, Tri-Tier structure).
- **`InvariantRules.md`**: Question-response invariant updated, language deference added to indent-2/newline-crlf, `@tsr` retired, SemVer arithmetic standardized.
- **`ReviewCommitGovernancePolicy.md`**: Restored standard SemVer arithmetic (`+0.0.1` Patch, `+0.1.0` Minor, `+1.0.0` Major) in `RULE-REV-007`.
- **`RepositoryContextPolicy.md`**: `RULE-CTX-006` updated for operator GoodMorning exclusivity; `RULE-CTX-001` headless fallback; `RULE-CTX-002` config.json location; `RULE-CTX-004` version.json link.
- **`DocumentationStandardsPolicy.md`**: Duplicate `RULE-DOC-008` resolved by introducing `RULE-DOC-003.1`; SemVer examples fixed.
- **`PowerShellStandardsPolicy.md`**: Codified `RULE-PS-025` (Model-Atom-Controller modular invariant).
- **`ProposalReviewFlowPolicy.md`**: Codified transparent single-window junction review (`<FollowSymLinks Value="True"/>`); corrected file count to 21; eliminated trailing `.iew.` typo.
- **`AGENTS.md` & `LCM-Rules-Cross-Reference.md`**: Restructured Master Cross-Reference Table to mirror the 3 tiers (`process/`, `quality/`, `lang/`), cataloging all 21 rule files.
- **`CLAUDE.md`**: Synchronized to SemVer `10.3.0` and Tri-Tier architecture.




