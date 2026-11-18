# Implementation Plan: CRP-332 - Workspace CRLF Line-Ending Enforcement

Module: docs/Proposals/332_CRP-Workspace-CRLF-Line-Ending-Enforcement/Implementation Plan CRP-332.md  
Purpose: Components and Gate 0 traceability of the CRLF enforcement implemented by Claude in DOIT.  
Path: LCM_Inventory/docs/Proposals/332_CRP-Workspace-CRLF-Line-Ending-Enforcement/Implementation Plan CRP-332.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Implemented (DOIT, awaiting Gate 2)  
Date: 2026-11-15 15:56:40

---

## 1. Problem Context

Hosts and tools write LF; Git converts only at commit/checkout, so LF stays on disk until the next checkout. Three repositories had no `.gitattributes`. Operator decision: CRLF everywhere, LF allowed only transiently, converted at the latest at completion.

## 2. Components and Gate 0 Traceability

| # | Component | Change | Gate 0 clause |
|:---|:---|:---|:---|
| 1 | `LCM_Inventory/modules/LcmLineEndingAtoms.psm1` (new) | Byte-level, BOM-preserving lone-LF -> CRLF atoms; type allow-list (`*.sh`, `*.go` excluded); junction-safe enumeration | Exit 2, 3, 4 |
| 2 | `LCM_Inventory/tests/LcmLineEndingAtoms.Tests.ps1` (new) | Pester v5 suite (RULE-PS-025) | Exit 2-4 verification |
| 3 | `LCM_Inventory/tools/Repair-LcmLineEndings.ps1` (new) | Controller: dry run default, `-Apply`, log in `data/logs/lcm/` | Exit 2 (one-time conversion) |
| 4 | `LCM_Inventory/tools/Submit-ReviewResult.ps1` (10.2.1 -> 10.2.2) | Normalizes every committable/staged path to CRLF before staging | Exit 3 (completion time) |
| 5 | `.gitattributes` in `LCM_Shared`, `LCM_Supervision`, `LCM_Tools` (new) | Copy of the LCM_AI block | Exit 1 |
| 6 | `LCM_AI/.claude/hooks/Invoke-ClaudeCrlfHook.ps1`, `LCM_AI/.claude/settings.json` (new, adapter) | PostToolUse hook (Write/Edit) converts Claude's writes immediately | Exit 4 |
| 7 | One-time conversion (no code) | 419 files converted (418 in the five LCM_* repos, 1 root file) | Exit 2 |
| 8 | `LCM_AI/.claude/translation/WORKPLAN.md` | D-17 amended by D-29 | Exit 5 |

## 3. Not Done (deliberately)

- No blocking LF gate (operator: LF is transient; Non-Goal).
- Tool catalog (`tools.db`) registration of `Repair-LcmLineEndings.ps1`: left to the governed catalog refresh at or after Gate 2 (D-22 corollary).
- GoodNight commit path (`--no-verify`) does not normalize; Git stores LF anyway and the next completion converts the working files.
