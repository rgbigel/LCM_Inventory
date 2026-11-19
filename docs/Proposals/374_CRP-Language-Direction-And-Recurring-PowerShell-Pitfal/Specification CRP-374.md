# Specification: CRP-374

Module: docs/Proposals/374_CRP-Language-Direction-And-Recurring-PowerShell-Pitfal/Specification CRP-374.md  
Purpose: Language Direction And Recurring PowerShell Pitfalls  
Path: LCM_Inventory/docs/Proposals/374_CRP-Language-Direction-And-Recurring-PowerShell-Pitfal/Specification CRP-374.md  
Authors: Rolf  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-19 17:18:18

```yaml
CRP-ID: CRP-374
Title: Language Direction And Recurring PowerShell Pitfalls
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 17:18:16
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator 2026-11-19 (recommendations accepted): Python is the default for new tools; existing PowerShell tools are
rewritten in Python instead of adjusted, gradually and never as a one-time effort; Go for daemon-class code; PowerShell
only where unavoidable, and the PowerShell errors we keep making are eliminated through PowerShellRules; AI ad-hoc work
in .py files.

## 2. Gate 0 Contract

### Target State

T1 A canonical language-selection rule (LanguagePolicy or a new rule ID) stating the direction above.

T2 PowerShellRules / PowerShellStandardsPolicy gain rules against the recurring errors seen on 2026-11-19: backtick
sequences inside double-quoted native arguments, inline `-c` code through PowerShell, line-ending dependent text
anchors, StrictMode and module scope leaking into child work (Pester in-process), `Set-Content` / `Out-File` writing
CRLF.

T3 Synced per RULE-AUTH-002 (AGENTS.md, Cross-Reference, Claude adapter, hashes).

### Invariants and Exit Criteria

- Exit: rules in place and synced; RULE-PY-010 (interpreter registry, CRP-366) referenced, not duplicated.

### Explicit Non-Goals

- Rewriting existing tools in this CRP (they move when touched).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## Operator Decisions (2026-11-19 17:32:57)

- New obligations get new rule IDs (e.g. `RULE-LANG-006`, `RULE-PS-026` onward); existing rules stay unchanged.
