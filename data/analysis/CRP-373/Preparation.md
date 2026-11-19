# CRP-373 Preparation: Readiness Gate Completeness Against The Rules

Module: data/analysis/CRP-373/Preparation.md  
Purpose: CRP-373 Preparation: Readiness Gate Completeness Against The Rules  
Path: LCM_Inventory/data/analysis/CRP-373/Preparation.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:27:06

---

## 1. Inventory

Canonical rules: 226 rule IDs and 51 named invariants.

| Rule file | Rule IDs | Named invariants |
|:---|---:|---:|
| `AnalysisGovernancePolicy.md` | 14 | 0 |
| `CMDRules.md` | 0 | 6 |
| `DecisionCascadeGovernancePolicy.md` | 11 | 0 |
| `DisplayStandardsPolicy.md` | 19 | 0 |
| `DocumentationStandardsPolicy.md` | 17 | 0 |
| `ElevationPolicy.md` | 7 | 0 |
| `GoRules.md` | 0 | 0 |
| `GoalFirstDesignPolicy.md` | 5 | 0 |
| `InvariantRules.md` | 0 | 23 |
| `JsonRules.md` | 0 | 7 |
| `LanguagePolicy.md` | 5 | 5 |
| `MethodEfficiencyPolicy.md` | 16 | 0 |
| `PowerShellRules.md` | 2 | 0 |
| `PowerShellStandardsPolicy.md` | 26 | 0 |
| `ProposalReviewFlowPolicy.md` | 44 | 0 |
| `PythonRules.md` | 10 | 10 |
| `RepositoryContextPolicy.md` | 8 | 0 |
| `ReviewCommitGovernancePolicy.md` | 21 | 0 |
| `RuleAuthority.md` | 5 | 0 |
| `SubsystemGovernancePolicy.md` | 9 | 0 |
| `macro-definitions.md` | 7 | 0 |

Gate tools:
- `Test-RepoReadiness.ps1`: [Gate 1/4] Universal general LCM readiness...; [Gate 2/4] Tripartite documentation...; [Gate 3/4] CM engine structure...; [Gate 4/4] Unit tests...
- `Test-GeneralReadiness.ps1`: [Gate 1/7] Validating .agents/rules Reparse Point...; [Gate 2/7] Validating File Encodings (UTF-8 No-BOM)...; [Gate 3/7] Validating PowerShell AST Syntax...; [Gate 4/7] Validating Python Source Syntax...; [Gate 5/7] Validating Git Secrets & Ignore Isolation...; [Gate 6/7] Validating Elevated Operations & Immutability Governance (RULE-ELEV-007)...; [Gate 7/7] Validating LCM Inventory Exclusivity (Proposals, DoT, scratch)...

Tests: 48 Pester files (gate 4); Python unit tests not yet in the gate: `test_claude_eol_hook.py`, `test_repair_lcm_line_endings.py`, `test_set_lcm_window_zone.py`.

Finding for the gate's test isolation: `tests/ToolIntentMetrics.Tests.ps1` calls `Update-LcmToolIntentCall` against the
live `config/tool_intents.json`, and `tests/LcmElevatedDaemon.Tests.ps1` instantiates the legacy daemon controller that
calls the same writer; every full gate run increments live call statistics (CRP-358 reconciliation, 7 rows).

## 2. Steps

1. Rule-to-check table: each rule ID / named invariant -> mechanical check in the gate, or "not mechanizable" (with
   reason). Output as a data file plus a Markdown view.
2. Missing mechanical checks added to the gate, ordered by cost; gate 4 runs Pester and `python -I -m unittest discover`.
3. Tests that write live stores switched to temporary copies (the finding above).

## 3. Dependencies

Last: the table must include the rules created by CRP-371 (relative paths), CRP-374 (language, PowerShell pitfalls) and
the hashing of CRP-372.

## 4. Operator Questions

1. Should the live-store writing of the two tests be fixed here (gate isolation) or as a separate BUG?
