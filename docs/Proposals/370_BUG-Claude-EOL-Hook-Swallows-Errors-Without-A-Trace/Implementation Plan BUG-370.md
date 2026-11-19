# Implementation Plan: BUG-370 - Claude EOL Hook Swallows Errors Without A Trace

Module: docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Implementation Plan BUG-370.md  
Purpose: Concrete changes per file for BUG-370.  
Path: LCM_Inventory/docs/Proposals/370_BUG-Claude-EOL-Hook-Swallows-Errors-Without-A-Trace/Implementation Plan BUG-370.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 16:26:01

---

| File | Change |
|:---|:---|
| `LCM_AI/.claude/hooks/invoke_claude_eol_hook.py` | errors and `failed` results of `repair_file` are appended to `LCM_Inventory/logs/claude-eol-hook.log`; exit 0 unchanged; `LCM_EOL_HOOK_LOG` overrides the path |
| `LCM_Inventory/tests/test_claude_eol_hook.py` (new) | 4 cases: convert without log, failed repair logged, invalid payload logged, no path silent |

## Open Items

- Hook command in `LCM_AI/.claude/settings.json` still names the hook script by an absolute in-root path. Claude Code freezes the hook configuration at session start, so a changed command cannot be tested in the running session. Next session: switch to a root-relative form (e.g. `$CLAUDE_PROJECT_DIR`), verify that the hook runs (a Write is converted and nothing is logged), otherwise revert.
- Operator 2026-11-19 (decided, implemented after the Gate 2 accepts): exit 2 with a one-line message on an error, in addition to the log.
