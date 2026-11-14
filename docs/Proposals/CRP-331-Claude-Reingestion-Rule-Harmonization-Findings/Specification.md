# Specification: CRP-331

Module: docs/Proposals/CRP-331-Claude-Reingestion-Rule-Harmonization-Findings/Specification.md  
Purpose: Findings and change recommendations from Claude's re-ingestion of the canonical LCM rules at LCM_AI 2bebbaa, addressed to Antigravity for analysis and joint design of the corrections.  
Path: LCM_Inventory/docs/Proposals/CRP-331-Claude-Reingestion-Rule-Harmonization-Findings/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Draft (awaiting operator review before Antigravity instruction)  
Date: 2026-11-14 21:03:53

```yaml
CRP-ID: CRP-331
Title: Claude Re-ingestion Findings and Rule Harmonization (Baseline 2bebbaa)
Scope: LCM_AI
Target Scope: LCM_AI/.agents/rules (governance rules); LCM support tools only where a rule correction requires it
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_AI, LCM_Inventory]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-14 19:40:52
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 9
App-ID: None
```

---

## 0. Registration Note

This bundle was created by Claude with the operator's authorization (option B, 2026-11-14): bundle first, ledger registration by Antigravity afterwards. The ledger entry for id 331 does not exist yet. Only `Specification.md` is provided; `Implementation_Plan.md` and `Walkthrough.md` follow from Antigravity's analysis.

## 1. Gate 0 Contract (RULE-GOAL-002)

- **Target State**: The canonical rules in `LCM_AI/.agents/rules/` contain no contradiction listed in section 3, every named tool or path exists (or is explicitly marked planned), and every item that CRP-326 section 6.2 records as implemented is present in the rules.
- **Binding Principle (applies to all work under this CRP)**: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity." (RULE-GOAL-002; see F-47 on its label.)
- **Exit Criteria**: For each finding, Antigravity records an accepted resolution (change, rejection with reason, or deferral); accepted changes pass the rule health check and the Claude adapter drift check reports 0 issues after re-synchronization.
- **Scope of code**: LCM support tools (the code of the LCM Model Support, mainly `LCM_Inventory/tools`, `modules`, `DoT`) are shared by all AI hosts and MUST NOT differ between Antigravity and Claude. Where a rule correction requires a tool change, Antigravity makes it once, for all hosts.
- **Explicit Non-Goals**: No changes to code of non-LCM governed repositories; no documentation (`docs/`) analysis (phase 3); no host-specific copies or variants of LCM tools; no change to Claude adapter files by Antigravity.

## 2. Method and Evidence

- Source: all 21 files in `LCM_AI/.agents/rules/` at commit `2bebbaa` (2026-11-14 18:58:18), working tree clean.
- Claude rebuilt its adapter `LCM_AI/.claude/rules/` 1:1 per RULE-AUTH-004 (10 process, 4 quality, 7 lang). A drift check (file set, tier, source version, 158 defined `RULE-*` IDs, encoding) reports 0 issues; a negative test confirmed it detects a missing ID.
- Existence statements ("does not exist") were checked on disk on 2026-11-14.
- Line numbers refer to the files at `2bebbaa`.
- Full register with all statuses: `LCM_AI/.claude/translation/FINDINGS.md` (IDs `C1-C6`, `F-01..F-47`).
- **Data authority (operator, 2026-11-14)**: the JSON data files (`proposals.json`, `config/tool_catalog.json`, ...) are being replaced by SQLite tables (`data/proposals/proposals.db`, `data/tools/tools.db`). Rules and agents MUST NOT rely on the JSON files; during the transition they are a fallback only. The textual `.sql` dumps are produced at push and are not synchronous with the tables. All recommendations below that name a JSON file are to be read with this in mind.

## 3. Contradictions and Unimplemented CRP-326 Items (discuss first)

### 3.1 F-18: Major version arithmetic contradicts itself
- **Evidence**: `DocumentationStandardsPolicy.md:92-95` (RULE-DOC-005) preserves minor and patch at a major step (`NewVersion = M.Y.Z`, `9.2.1` -> `10.2.1`). `ReviewCommitGovernancePolicy.md` RULE-REV-007 and `InvariantRules.md` single-commit-version-increment reset minor and patch to 0 for all components (`10.2.5` -> `11.0.0`).
- **Recommendation**: Restate RULE-DOC-005 with the reset semantics (operator decision 2026-11-13: version bump +1.0.0 resets the lower digits for all parts).
- **Decision needed**: Confirm that REV-007/INV semantics win.

### 3.2 F-19: Indentation deference points to rules that do not exist
- **Evidence**: `InvariantRules.md:31` and `RuleAuthority.md:56` state that GoRules mandates hard tabs (`gofmt`) and PythonRules 4 spaces (PEP 8). Neither `GoRules.md` nor `PythonRules.md` contains an indentation rule, so the 2-space default still governs Go and Python.
- **Recommendation**: Add `indentation` rules to `GoRules.md` (tabs via `gofmt`) and `PythonRules.md` (4 spaces, PEP 8), or remove the claims.

### 3.3 F-20 (C4, CRP-326 item 4): Old lifecycle vocabulary still present
- **Evidence**: `ProposalReviewFlowPolicy.md:124` (`Proceed` via `Suggested -> Scoped -> Decided -> ... -> Committed -> Published`), `:128-130` (`COMPLETE` -> `Committed`, `PUBLISH` `Committed -> Published`, `cancel` -> `Cancelled`), `:170` and `:205` (7 Sync Points and matrix), `:186` (`Cancelled` disposition), `:343` (RULE-LCM-016 `REVIEW -> COMMITTED`); `ReviewCommitGovernancePolicy.md:61` (RULE-REV-006 `REVIEW -> COMMITTED`); RULE-REV-001.2 "before reaching `COMMITTED`"; `DisplayStandardsPolicy.md` RULE-DSP-003.3 status rail (`... Held -> Cancelled`) and RULE-DSP-011 timeline. RULE-LCM-007 mixes both vocabularies: matrix (sync points) vs state diagram (`In_Review`, `Completed`, `Pushed`, `Withdrawn`). Verbs differ: `cancel` vs table `withdraw`; `resume` vs table `continue` vs macro `ReOpen`.
- **Recommendation**: Rewrite these passages onto the authoritative flat state table (RULE-LCM-002); keep the sync points only as a labelled historical mapping; one verb per transition (`withdraw` or `cancel`, `continue` or `resume`).
- **Note**: CRP-326 section 6.2 does not list this change, although item 4 planned it.

### 3.4 F-21: Review tool and baseline model are inconsistent
- **Evidence**: `Invoke-BeyondCompareReview.ps1` is the named review tool in `ProposalReviewFlowPolicy.md:143,147,272`, `ReviewCommitGovernancePolicy.md:21,59`, `MethodEfficiencyPolicy.md:49`, `macro-definitions.md:158`; the file does not exist in `LCM_Inventory/tools/`. `ReviewCommitGovernancePolicy.md:134-136` (RULE-REV-014) makes BCR (`BCR.cmd` / `Invoke-MacriumBcrReview.ps1` / `Invoke-MacriumDailyBcrBaseline.ps1`, workspace root, Macrium image) the ONLY valid comparison and prohibits single-repository subtrees, while RULE-LCM-004 prescribes `Invoke-BeyondCompareReview.ps1 <RepoName>` and RULE-REV-008 a Git `BaseCommit` export baseline.
- **Recommendation**: Name one review entry point and one baseline model; align LCM-004, LCM-008, REV-001, REV-006, REV-008, EFF-004 and macro BCR with RULE-REV-014 (or narrow REV-014).

### 3.5 F-22: `LCM_Inventory/config.json` does not exist
- **Evidence**: referenced in `RepositoryContextPolicy.md:28` (RULE-CTX-002, changed by CRP-326), `ElevationPolicy.md:29,46` (ELEV-001/003; ELEV-004 implies it), `SubsystemGovernancePolicy.md:29,38` (SUB-001/003), `DocumentationStandardsPolicy.md:96` (DOC-005.4). No `config.json` exists anywhere in `LCM_Inventory`; repository elevation data (`ElevationRequired`, `MinimumPrivilege`) lives in `LCM_Inventory/data/inventory.json`.
- **Operator decision (2026-11-14, Q-05)**: There is no per-repository LCM configuration. Governance is in the rules (common) and in `docs/` (subsystem-specific).
- **Recommendation**: Remove the `LCM_Inventory/config.json` references from RULE-CTX-002, RULE-ELEV-001/003/004, RULE-SUB-001/003 and RULE-DOC-005.4; state where each fact lives instead (rules, or the repository's `docs/`; elevation per tool in the `tools.admin` column of `data/tools/tools.db`, JSON catalog only as transition fallback). Clarify the role of the per-repository fields in `data/inventory.json` (`ElevationRequired`, `MinimumPrivilege`), which are generated audit data (RULE-EFF-001/003).

### 3.6 F-42 / F-46 (C5, CRP-326 item 5): Implementation record vs rules
- **Evidence**: CRP-326 section 6.2 records CTX-002 "config.json location" as fixed (see F-22) and does not mention items 4 and 5. The rules reference `proposals.json` 9 times (`ProposalReviewFlowPolicy.md:23,202,290,310,324,377,402,436`, `ReviewCommitGovernancePolicy.md:82`) and never `proposals.db`, `Sync-LcmProposalsDb.ps1` or `Update-Proposal.ps1`. CRP-326 6.2 states `version.json` 10.3.0; the file shows 10.6.4.
- **Operator decision (2026-11-14, Q-03)**: `proposals.db` is authoritative; `proposals.json` is a transition fallback only and will be removed; `proposals.sql` is dumped at push, not synchronously.
- **Recommendation**: Replace the 9 `proposals.json` references with the ledger in `proposals.db`, accessed only through the governed tools (`Update-Proposal.ps1`, `Invoke-ProposalAction.ps1`, `Sync-LcmProposalsDb.ps1`), no manual writes; state the JSON fallback and its end; implement item 4 (F-20); correct the CRP-326 record.

## 4. Further Contradictions

| ID | Evidence | Recommendation |
|:---|:---|:---|
| F-27 | `ProposalReviewFlowPolicy.md:200-201` (RULE-LCM-007.5) archives plans in `LCM_Inventory/data/proposals/plans/` (does not exist); RULE-LCM-020 uses bundles, purge after push, Git retrieval. | Keep the bundle model; retire the plans path. |
| F-28 | `ProposalReviewFlowPolicy.md:137` default `coarse`; `DecisionCascadeGovernancePolicy.md:79` every push resets to `tight`. | Decide the post-push default and state it once. |
| F-40 | `DisplayStandardsPolicy.md:109` terminate stale display/diff windows; `ReviewCommitGovernancePolicy.md:113` must not kill operator BC instances. | Exclude operator-owned Beyond Compare windows from DSP-008.5. |
| F-41 | `ProposalReviewFlowPolicy.md:436` `"state": "completed [minimal-tests]"`; not a value of the flat state table nor of the `proposals.state` CHECK constraint (`docs/DataDesign-Proposals.md`). Also RULE-REV-002.4, RULE-DEC-004/005. | Keep `state: completed` plus `test_scope: minimal`. |
| F-29 | RULE-LCM-034 (`ProposalReviewFlowPolicy.md:550`) duplicates RULE-SUB-008 (`SubsystemGovernancePolicy.md:80`); both list `LCM_SystemConfiguration` (does not exist), while SUB-008.4 names `SystemConfiguration` a disjunct subsystem. | One owner; correct the repository list. |

## 5. Stale References and Gaps

| ID | Evidence | Recommendation |
|:---|:---|:---|
| F-23 | `ElevationPolicy.md:69,83` lists `Invoke-PrivilegedTool.ps1` and `Invoke-InteractiveDesktop.ps1` (retired by CRP-320) next to DO; `PowerShellStandardsPolicy.md:156-166` (RULE-PS-011) and `DisplayStandardsPolicy.md:99-104` (RULE-DSP-008) mandate `Invoke-InteractiveDesktop.ps1`, path given as `LCM_Tools\...` (file is in `LCM_Inventory\tools\`). | DO (`LCM_Inventory\DoT\do.exe`) as the single dispatch route; record the retirement. |
| F-24 | `MethodEfficiencyPolicy.md:71` names `LCM_Inventory/tools/tool_catalog.json`; the JSON catalog is at `LCM_Inventory/config/tool_catalog.json` and is being replaced by `data/tools/tools.db` (CRP-323). RULE-ELEV-006 also names the JSON catalog. | Name `tools.db` (and its query tools, e.g. `Show-ToolIntents.ps1`) as the discovery and elevation source; JSON only as transition fallback. |
| F-25 | `MethodEfficiencyPolicy.md:45` `Invoke-LCMUpdate.ps1` does not exist. | Remove or name the replacement. |
| F-26 | RULE-ANA-006 `active_session.json`: location unspecified, not in `LCM_Inventory/data/`. | State the path. |
| F-36 | `InvariantRules.md` syntax gate lists `*.cmd`; no parser named (also F-07 for `*.psd1`, `*.md`, `*.html`, `*.js`, `*.sql`, `*.yaml`). | Name a check per type or state "no gate". |
| F-38 | `ReviewCommitGovernancePolicy.md:44` review state `DEFERRED`; lifecycle uses `held`. | Use `held`. |
| F-33 | `macro-definitions.md:8` claims source authority `LCM_Inventory/.agents/rules/...` (junction to LCM_AI); `:390` `tsr` macro still "automated on every turn"; headers of macro-definitions, PowerShellRules, GoRules, LanguagePolicy deviate from RULE-DOC-003.2. | Fix authority line; drop `tsr`; normalize headers. |
| F-37 | `GoRules.md` header template hardcodes `VERSION: 10.2.0`, `AUTHOR: Rolf`, change log `10.0.0`; `ENCODING: ASCII` vs UTF-8 rule. | Placeholders aligned with DOX and RULE-REV-007. |

## 6. Imprecision and Redundancy

| ID | Evidence | Recommendation |
|:---|:---|:---|
| F-30 | RULE-LCM-024 and RULE-REV-010 syntax gates lack Go (INV has it); RULE-LCM-028 keeps the old question example replaced in INV. Also RULE-LCM-029, RULE-PS-021 restate INV. | INVARIANT-RULES as single owner; others reference it. |
| F-34 | RULE-AUTH-004 loading scope vs frontmatter: DocumentationStandardsPolicy `globs: "*.md"` (quality = universal); PowerShellRules and DisplayStandardsPolicy `globs: "*"` (lang = path-scoped); GoRules `alwaysApply: true`. | Align globs with AUTH-004. |
| F-35 | Date format: RULE-PS-008 and RULE-DOC-003 template `YYYY-MM-DD`; RULE-DOC-010 mandatory `YYYY-MM-DD HH:mm:ss`; INV allows either. | One format per file class. |
| F-39 | RULE-LCM-009.2 header fields (Target Scope, Affected Version Range, Impacted Repositories) vs RULE-LCM-012.3 YAML keys. | One schema (this CRP uses both). |
| F-43 | RULE-LCM-030 and GoodMorning/GoodNight macros mandate emoji messages; macro `technical` forbids emojis/unicode. | State precedence. |
| F-44 | `MethodEfficiencyPolicy.md:111` "Agents must operate in direct execution mode" is unconditional; Gate 1 halt (RULE-LCM-014) and Gate 0 pause (RULE-GOAL-002) apply outside DOIT. | Scope the sentence to DOIT. |
| F-09 | INV `no-verbosity` vs `zero-conversational-padding`; INV `english-default-language` vs LanguagePolicy. | One owner each. |
| F-14 | RULE-GOAL-002 "structural, cross-cutting, materially ambiguous, scope-expanding" undefined. Operator context (2026-11-13): BUG -> no Gate 0 pause; DOIT -> run to Gate 2; pause only for a CRP in standard flow with non-evident target. | Codify the context-based trigger. |
| F-15 | `LanguagePolicy.md`: Antigravity banner, `Changelog:` instead of Status/Date, no `RULE-*` IDs. | Align header; introduce `RULE-LANG-001..005`. |
| F-47 | RULE-GOAL-002 (also RULE-DOC-003.1) calls "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity" the "default Non-Goal". Listed under Non-Goals it reads as excluded, although it is the binding principle of all work (operator: "the bible"). | Label it as a binding principle / invariant of every Gate 0 Contract, not as a Non-Goal. |

## 7. Host-Context Items (no rule error; adapter annotations)

| ID | Item | Recommendation |
|:---|:---|:---|
| F-31 | RULE-LCM-022 (`multi_replace_file_content`, editor pending-diff state, `files.autoSave`), RULE-LCM-021.2 bare-word `@` popup, RULE-ANA-001.2 tool names, RULE-ANA-007 `files/` workspace, macros `ar` (host transcript provider) and `S` (copilot profile). | State the host-neutral intent in the rule; keep host mechanics as adapter annotations (RULE-AUTH-001.3). |
| F-32 | `AnalysisGovernancePolicy.md:31` (RULE-ANA-000) Check 0 compares `.copilot/Rules/` hashes; translated adapters can never hash-match. | Per-adapter Check 0: baseline commit equality plus clean canonical tree. |
| F-45 | RULE-AUTH-001.4 names `Test-LCMRuleHealth.ps1` for adapter drift; support for translated adapters unverified. | Specify the adapter drift check and host it in a governed tool. |
| F-16 | Claude's timestamp-header waiver (operator decision 2026-11-13) has no canonical host-exception provision. | Add a host-exception provision or record it in overrides. |

## 8. Open Operator Decisions

| ID | Question |
|:---|:---|
| Q-02 | Answered (2026-11-14): where Claude's built-in tools are not suited (`es.exe` and the other named external tools), Claude MUST run the external tool through the DO gateway (`LCM_Inventory\DoT\do.exe "<command>" -sync`); built-in search is the escape hatch, with the reason stated. Recommendation: state this host-neutrally in RULE-EFF-007. |
| Q-04 | Answered (2026-11-14): Claude may and should write to `.agents/LEARNED_ADVICE.md` (`/learn`, RULE-CTX-005). |
| Q-05 | Answered (2026-11-14): no per-repository LCM configuration exists; see 3.5 (F-22). |
| Q-03 | Answered (2026-11-14): SQLite tables are authoritative; JSON files are transition fallback only; see section 2 and 3.6. |

## 9. Design Topic: Host-Neutral Session Continuity (GoodNight / GoodMorning Convergence)

Operator intent (2026-11-14): every AI host follows the same scheme. When a host is "done" with a session it performs its good-night: it writes into the workspace what it wants to find again. At its good-morning it reads that back. Friction where Antigravity's data meets Claude's data is expected and will be worked out later; this section records the concept and the known friction points so the design can start from them.

### 9.1 Current State

| Aspect | Antigravity | Claude |
|:---|:---|:---|
| Session close | `GoodNight` (`Invoke-LCM_GoodNight.ps1 [-Push]`): saves session memory to `.agents/ACTIVE_CONTEXT.md`, records Quiescent state in `.agents/ACTIVE_SESSION.md`, archives daemon logs, commits (optionally pushes), final timestamp banner (RULE-LCM-030). | Overwrites `LCM_AI/.claude/translation/SESSION_HANDOFF.md` (last session, next step, open items) and ends with a "Next step" line. Commits and pushes like Antigravity, only through the governed tools (`COMPLETE` / `Submit-ReviewResult.ps1`, `PUBLISH` / `Invoke-LCM_Push.ps1`), never raw git. |
| Session start | Operator runs `GoodMorning` (operator-exclusive, RULE-CTX-006); AI reads `ACTIVE_SESSION.md`, `ACTIVE_CONTEXT.md`, `LEARNED_ADVICE.md`, reports attention items, references the GoodNight timestamp. | Reads `WORKPLAN.md` and `SESSION_HANDOFF.md` (root `CLAUDE.md` section 4); reads the `.agents` files (RULE-CTX-005/006) and writes learned-advice candidates (SC-6). |
| Long-term memory | `LEARNED_ADVICE.md` (Accepted binding, Candidates guidance) and rules. | `WORKPLAN.md` (charter, decisions, open questions); host-private auto-memory holds pointers only. |
| Per-CRP evidence | `Implementation_Plan.md`, `Walkthrough.md` in the bundle. | Same documents (Claude section), per operator decision 2026-11-14. |

### 9.2 Target Concept

1. **One host-neutral continuity layer in workspace files.** Three kinds of content: (a) charter and decisions (long-lived), (b) session state and next step (overwritten per session), (c) learned advice (reviewed, binding when accepted). Per-CRP evidence stays in the bundle.
2. **Each host performs its own good-night and good-morning** against that layer, using the same structure. A host's good-night writes only its own session state and candidates; it never runs another host's tools.
3. **Host-native memory holds pointers only** (Claude auto-memory, Antigravity projects when introduced); the files are the authority (operator principle: files on disk are the only trusted state).
4. **The operator's GoodMorning** remains the operator-exclusive report and should read every host's session state, so attention items from all hosts appear in one place.

### 9.3 Known Friction Points (to be resolved jointly)

| ID | Friction | Question to decide |
|:---|:---|:---|
| SC-1 | Concurrent writes: two hosts updating the same continuity file. | Operator (2026-11-14): concurrent work is not allowed; coordination is the operator's responsibility. A one-sided change MUST be announced to the other host. The data stored on disk wins every contest, not Git. |
| SC-2 | Formats differ (`ACTIVE_SESSION.md` / `ACTIVE_CONTEXT.md` vs `SESSION_HANDOFF.md` / `WORKPLAN.md`). | Common schema (headings, fields, timestamps) for the shared layer. |
| SC-3 | Quiescence (RULE-LCM-030): after an Antigravity GoodNight the workspace is Quiescent; a Claude session may still be active, or start later. | Is Quiescent per host or per workspace? Does a Claude good-night set or require it? |
| SC-4 | GoodMorning gap and staleness detection currently refer to Antigravity's last activity. | Track last activity per host; report the gap per host. |
| SC-5 | Commit ownership: both hosts commit and push, only through the governed tools (RULE-REV-001, RULE-LCM-013). Claude's state files under `LCM_AI/.claude/` are untracked and could be swept into a GoodNight commit. | Which files a host's GoodNight may commit; whether Claude's state is versioned. |
| SC-6 | Learned advice from two hosts (RULE-CTX-005). | Operator (2026-11-14): Claude may and should write to `LEARNED_ADVICE.md`. Authorship: the operator is always named first; an AI host adds its name (ahead of the other AI host) only if it changes something. |
| SC-7 | Removal of information (RULE-LCM-031). | Operator (2026-11-14): information is removed only manually by the operator (rare) or automatically when a CRP is accepted. |
| SC-8 | Until synchronization, Claude keeps its session continuity separate (Claude decision D-11); learned advice is already shared (SC-6). | Transition path from separate files to the shared layer. |

### 9.4 Rules Affected When Designed

RULE-CTX-005, RULE-CTX-006, RULE-LCM-030, RULE-LCM-031, macros `GoodMorning` / `GoodNight` / `learn`, RULE-AUTH-001 (host adapters).

## 10. Resolved Since 43e36b0 (for the record)

C1, C2 (see F-18), C3, C6, F-01, F-02, F-03, F-04, F-06, F-11, F-12, F-13, F-17. Partial: F-07 (Go added, F-36 open), F-08 (INV updated, F-30 open), F-16 (`@tsr` retired).
