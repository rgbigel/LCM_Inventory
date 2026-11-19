# Implementation Plan: BUG-365 - Line Ending Convergence Across Workspace

Module: docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Implementation Plan BUG-365.md  
Purpose: Concrete changes per file for BUG-365 and its open items.  
Path: LCM_Inventory/docs/Proposals/365_BUG-Line-Ending-Convergence-Across-Workspace/Implementation Plan BUG-365.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 11:47:30

---

## 1. Changes (done 2026-11-19)

| # | File | Change |
|:---|:---|:---|
| 1 | `LCM_Inventory/tools/Repair-LcmLineEndings.py` (new) | Policy source and CLI (dry run, `--apply`, `--stdin`, `--json`); Python rewrite replacing the PowerShell atom |
| 2 | `LCM_Inventory/tests/test_repair_lcm_line_endings.py` (new) | 11 unittest cases, replacing `LcmLineEndingAtoms.Tests.ps1` |
| 3 | `LCM_Inventory/modules/LcmLineEndingAtoms.psm1`, `tools/Repair-LcmLineEndings.ps1`, `tests/LcmLineEndingAtoms.Tests.ps1` | Deleted (retired) |
| 4 | `LCM_Inventory/tools/Submit-ReviewResult.ps1` (10.2.7) | Completion-time normalization calls the Python tool (paths on stdin) |
| 5 | `LCM_AI/.claude/hooks/invoke_claude_eol_hook.py` (new), `Invoke-ClaudeCrlfHook.ps1` (deleted), `LCM_AI/.claude/settings.json` | Claude PostToolUse hook in Python |
| 6 | `.gitattributes` in the root and all 22 repositories | Canonical table; repository-specific comments and directives kept below it |
| 7 | `.vscode/settings.json` (root and 7 repositories) | `files.eol` LF, `[bat]` CRLF |
| 8 | Canonical rules (ADMINMODE on): `InvariantRules.md` 10.3.1 (`newline-crlf` -> `newline-lf`), `JsonRules.md` 10.2.1, `PowerShellRules.md` 10.2.2, `ProposalReviewFlowPolicy.md` 10.3.5 | Rule text; `CMDRules.md` `newline-crlf` stays (correct for cmd/bat) |
| 9 | RULE-AUTH-002 sync: `LCM_AI/AGENTS.md`, root `AGENTS.md`, `LCM_AI/docs/LCM-Rules-Cross-Reference.md`, Claude adapter (InvariantRules, JsonRules, PowerShellRules, ProposalReviewFlowPolicy), `CANONICAL_HASHES.md` | Same wording; all 21 hashes renewed |
| 10 | One-time conversion of the git root (`Git_Repositories`) | 1898 + 104 files converted; second pass found 0 left |
| 11 | Tool catalog (`Update-ToolCatalog.ps1`) | Launcher `RepairLcmLineEndings` now points to the `.py` |

## 2. Open Items

- Commit: Git shows the conversion as modifications where the index still held CRLF (LCM_Inventory 1181 paths, LCM_AI 152, OutlookVBAConversion 122, LCM_Tools 92, root 59, others fewer). Until committed, a checkout writes CRLF back. The working trees also hold other WIP (CRP-343, BUG-364), so the commit scope is the operator's `COMPLETE`.
- 76 PowerShell writers still produce CRLF (top: `Update-ToolCatalog.ps1`, `ProposalManager.psm1`, `Sync-LcmCatalogMacros.ps1`, `Save-AllSessionMemory.ps1`). Repository content stays LF anyway (`text=auto eol=lf` on add, completion-time normalization); they are fixed when rewritten in Python.
- `GEMINI.md` and the Antigravity adapter contain no line-ending statement; nothing to sync.
- `ACTIVE_CONTEXT.md` line 68 (`files.eol` CRLF, "Option B pending") is stale; continuity file, changed only on verified acceptance or operator deletion (RULE-LCM-031 (4)).
