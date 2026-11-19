# CRP-374 Preparation: Language Direction And Recurring PowerShell Pitfalls

Module: data/analysis/CRP-374/Preparation.md  
Purpose: CRP-374 Preparation: Language Direction And Recurring PowerShell Pitfalls  
Path: LCM_Inventory/data/analysis/CRP-374/Preparation.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Analysis (preparation, read-only; nothing implemented)  
Date: 2026-11-19 17:27:06

---

## 1. Inventory (rule files and sync targets)

| File | Version | Last rule ID |
|:---|:---|:---|
| `LCM_AI/.agents/rules/LanguagePolicy.md` | 10.3.0 | RULE-LANG-005 |
| `LCM_AI/.agents/rules/PowerShellRules.md` | 10.2.2 | RULE-PS-024 |
| `LCM_AI/.agents/rules/PowerShellStandardsPolicy.md` | 10.3.0 | RULE-PS-025 |
| `LCM_AI/.agents/rules/PythonRules.md` | 10.2.1 | RULE-PY-010 |
| `LCM_AI/.claude/rules/quality/LanguagePolicy.md` | 10.6.4 | RULE-LANG-005 |
| `LCM_AI/.claude/rules/lang/PowerShellRules.md` | 10.6.5 | RULE-PS-024 |
| `LCM_AI/.claude/rules/lang/PowerShellStandardsPolicy.md` | 10.6.4 | RULE-PS-025 |
| `LCM_AI/AGENTS.md` | None | None |
| `AGENTS.md` | None | RULE-PY-001 |
| `LCM_AI/docs/LCM-Rules-Cross-Reference.md` | 10.7.4 | RULE-PY-010 |

New rule IDs would be `RULE-LANG-006` (language selection) and `RULE-PS-026` onward (pitfalls), unless the operator
prefers extending existing IDs.

Recurring errors observed on 2026-11-19 (evidence for the pitfall rules): backtick sequences inside double-quoted native
arguments turned into real control characters (inline `-c` Python); exact-once text anchors failing on CRLF/LF; a
JSON-escaped anchor not matching file text; Pester run in-process after `Set-StrictMode` and module imports (BUG-364);
`Set-Content` / `Out-File` writing CRLF (76 of 187 PowerShell files, BUG-365).

Rewrite candidates of the CRP-366 open items (inline `-c` Python): `LCM_Inventory/tools/Test-LcmStrategyConsistency.ps1`
(line 98), `LCM_Inventory/tools/Archive-Clean.ps1` (199, 353), `LCM_Inventory/tools/Archive-Conversations.ps1` (182, 307,
344), `LCM_Inventory/tests/ToolPermissionLevels.Tests.ps1` (37, 60).

## 2. Steps

1. Rule texts (ADMINMODE): language-selection rule; pitfall rules with the evidence above; RULE-PY-010 referenced.
2. RULE-AUTH-002 sync: `LCM_AI/AGENTS.md`, root `AGENTS.md` quick reference, `LCM-Rules-Cross-Reference.md`, Claude
   adapter (LanguagePolicy, PowerShellRules, PowerShellStandardsPolicy), hashes (with the CRP-372 helper).
3. Rewrites are not part of CRP-374 (they move when touched): the four inline `-c` tools are assigned in the combined plan.

## 3. Dependencies

After CRP-372; before the code repairs of CRP-371 and the rewrites inside CRP-358, which then follow the new rules.

## 4. Operator Questions

1. New rule IDs (`RULE-LANG-006`, `RULE-PS-026`+) or extensions of existing IDs?
