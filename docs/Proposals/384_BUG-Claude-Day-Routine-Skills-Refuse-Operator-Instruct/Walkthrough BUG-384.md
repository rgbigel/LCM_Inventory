# Walkthrough: BUG-384 - Claude Day Routine Skills Refuse Operator Instruction

Module: docs/Proposals/384_BUG-Claude-Day-Routine-Skills-Refuse-Operator-Instruct/Walkthrough BUG-384.md  
Purpose: Path taken and test evidence of BUG-384.  
Path: LCM_Inventory/docs/Proposals/384_BUG-Claude-Day-Routine-Skills-Refuse-Operator-Instruct/Walkthrough BUG-384.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Verified  
Date: 2026-11-20 15:58:54

---

## Path Taken

- `LCM_AI/.claude/skills/goodmorning/SKILL.md`, `.../goodnight/SKILL.md`: frontmatter line
  `disable-model-invocation: true` removed (the only change).
- `LCM_AI/.claude/hooks/invoke_claude_session_title_hook.py` (new): SessionStart hook; for source `startup` it
  returns `hookSpecificOutput.sessionTitle` = `YYYY-MM-DD HH:mm:ss`; other sources return nothing.
- `LCM_AI/.claude/settings.json`: `SessionStart` hook (matcher `startup`) added before the existing PostToolUse hook.
- The capability was verified in the installed Claude Code build (hook output schema of `SessionStart` and
  `UserPromptSubmit` carries `sessionTitle`), not assumed.

## Test Evidence (2026-11-20)

| Check | Result |
|:---|:---|
| `python -m py_compile` hook | clean |
| `settings.json` `ConvertFrom-Json` | clean |
| Hook with `{"source":"startup"}` / `{"source":"resume"}` | title JSON / no output, exit 0 |
| Fresh session `claude -p` | transcript record `custom-title` = `2026-11-20 11:30:57` |
| Skill listing after the flag removal (running session) | `goodmorning` and `goodnight` offered as invocable skills |

## Operator Decision Q1 (2026-11-20, option A)

- `LCM_AI/.claude/settings.json`: `permissions.defaultMode: "acceptEdits"` is the LCM default for every Claude
  session in the workspace (file edits without a per-edit prompt; shell commands keep their permission rules;
  commits still only through Gate 2 and COMPLETE). JSON parse clean.
- `CLAUDE.md` section 4 (local, not in Git): when the first message is `goodmorning`, the GoodMorning reply is the
  start check; no separate start report (operator 2026-11-20).

## Operator Live Test (2026-11-20 15:58:54)

| # | Step | Result |
|:---|:---|:---|
| 1 | new session, first message `Hello` (no switch, no GoodMorning) | session named after its start timestamp: passed. The session gave a start report from `CLAUDE.md` section 4 (RULE-CTX-006), not from the hook |
| 2 | GoodMorning skill on operator instruction in a new session | passed |

Operator remark on the test design: a first message that mixes another request with the skill tests the other
request first; the title test uses a plain message.
