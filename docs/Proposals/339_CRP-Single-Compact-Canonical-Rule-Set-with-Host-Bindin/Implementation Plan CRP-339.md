# Implementation Plan: CRP-339 - Single Compact Canonical Rule Set with Host Bindings

Module: docs/Proposals/339_CRP-Single-Compact-Canonical-Rule-Set-with-Host-Bindin/Implementation Plan CRP-339.md  
Purpose: How the Gate 0 target of CRP-339 is reached: pilot, format decision, rollout, switch, verification.  
Path: LCM_Inventory/docs/Proposals/339_CRP-Single-Compact-Canonical-Rule-Set-with-Host-Bindin/Implementation Plan CRP-339.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.7.4
Status: Draft  
Date: 2026-11-16 17:16:26

---

## 1. Precondition

Starts only after the open cohort CRP-331..336 is completed (Specification non-goal).

## 2. Steps and Gate 0 Traceability

| Step | Content | Serves (Specification section 2) |
|:---|:---|:---|
| 1. Pilot (Claude) | Compact drafts of 2-3 canonical files (one MUST/MUST NOT line per rule, IDs kept), their `docs/Rules/<PolicyName>.md` counterparts and mapping tables; starting text = existing Claude projection without `[Claude]` notes. | Target 1, 2; Invariant "no normative loss" |
| 2. Format decision | Operator (and Antigravity) review the pilot; accept format and size target. | Exit criterion 1 |
| 3. Rollout | Remaining files; both frontmatter keys; host binding files from the 43 `[Claude]` annotations and the Antigravity specifics. | Target 1-4; exit criterion 2 |
| 4. Switch | Junction `LCM_AI/.claude/rules` -> `LCM_AI/.agents/rules`; `CLAUDE.md` / `AGENTS.md` reference the binding files; `AGENTS.md` quick reference, cross-reference, `Update-Gemini.ps1`, `Test-LCMRuleHealth.ps1` updated; translation artifacts and hash check retired. | Target 5; exit criteria 4, 5 |
| 5. Verification | Size measurement, ID completeness, mapping table, `claude -p` loading test (always-on + one path-scoped rule); Antigravity loading checked in the operator's Gate 2 live test; BCR. | Exit criteria 1-3, 6 |

## 3. Rollback

Daily Macrium baseline, then Git (operator 2026-11-16).