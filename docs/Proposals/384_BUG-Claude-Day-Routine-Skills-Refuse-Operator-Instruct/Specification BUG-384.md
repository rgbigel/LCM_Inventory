# Specification: BUG-384

Module: docs/Proposals/384_BUG-Claude-Day-Routine-Skills-Refuse-Operator-Instruct/Specification BUG-384.md  
Purpose: Claude Day Routine Skills Refuse Operator Instruction  
Path: LCM_Inventory/docs/Proposals/384_BUG-Claude-Day-Routine-Skills-Refuse-Operator-Instruct/Specification BUG-384.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Review  
Date: 2026-11-20 12:01:10

```yaml
CRP-ID: BUG-384
Title: Claude Day Routine Skills Refuse Operator Instruction
Scope: LCM_AI
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-20 12:01:10
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 6
App-ID: None
```

---

## 1. Executive Summary & Intent

The operator wrote "show date ... first, then: /goodmorning" (2026-11-20). Claude could not run the skill: the
frontmatter of `LCM_AI/.claude/skills/goodmorning/SKILL.md` and `.../goodnight/SKILL.md` carries
`disable-model-invocation: true`. Claude set this flag on 2026-11-14 (commit `0b5b6f2`) to enforce the then
operator-exclusive GoodMorning (RULE-CTX-006 at `2bebbaa`). CRP-350 (2026-11-17) allowed AI hosts to run
GoodMorning / GoodNight on explicit operator instruction (RULE-LCM-030 (6)), but the flag was not removed. It now
blocks exactly what the rule allows; "never on the AI's own initiative" is a behavioural rule and needs no flag.

Carried along (operator 2026-11-20, decision B): every newly started Claude session is named after its start
timestamp (`YYYY-MM-DD HH:mm:ss`) by a SessionStart hook.

- Review: this Specification and the two changed skill files, the new hook and `.claude/settings.json`.

## 2. Gate 0 Contract

### Target State

1. Both day-routine skills run when the operator instructs Claude in a message (also inside a longer message).
2. A newly started Claude Code session (source `startup`) carries its start timestamp as session name; resumed,
   cleared or compacted sessions keep their name.

### Invariants and Exit Criteria

- RULE-LCM-030 (6) unchanged: never on the AI's own initiative.
- Hook: `invoke_claude_session_title_hook.py` passes `py_compile`; `settings.json` passes `ConvertFrom-Json`.
- Live test (operator): a new session in the VS Code panel shows the timestamp as its name; "then: /goodmorning"
  inside a message runs the skill.

### Explicit Non-Goals

- No change to the GoodMorning / GoodNight scripts.
- Root-relative hook commands (absolute interpreter path stays, bootstrap exception RULE-PY-010).
