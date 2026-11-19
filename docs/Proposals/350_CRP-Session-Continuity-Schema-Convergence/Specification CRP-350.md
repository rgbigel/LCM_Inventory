# Specification: CRP-350

Module: docs/Proposals/350_CRP-Session-Continuity-Schema-Convergence/Specification CRP-350.md  
Purpose: Session Continuity Schema Convergence  
Path: LCM_Inventory/docs/Proposals/350_CRP-Session-Continuity-Schema-Convergence/Specification CRP-350.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Pushed  
Date: 2026-11-17 15:40:19

```yaml
CRP-ID: CRP-350
Title: Session Continuity Schema Convergence
Scope: LCM_Inventory, LCM_AI
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-17 15:28:03
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 9
App-ID: None
```

---

## 1. Executive Summary & Intent

Both AI hosts write `.agents/ACTIVE_SESSION.md`, but the same words mean different things to them. On 2026-11-17, Antigravity's good-morning reported Claude's host close (2026-11-16 22:02:57) as the workspace GoodNight. This CRP sets one written schema for the continuity layer, gives every section exactly one writer, and makes both hosts follow it.

The operator made two further decisions on 2026-11-17:

- **Day routines (option A):** when this CRP is accepted, the rule that forbids AI hosts to run `Invoke-LCM_GoodMorning.ps1` / `Invoke-LCM_GoodNight.ps1` is removed. The trigger is still an operator instruction.
- **No host-exclusive open items:** while one host is working, no open item may exist that only the other host can perform. The working host takes over everything, including the other host's adapter files.

This CRP takes over CRP-331 section 9 SC-2 (common schema), SC-3 (per-host vs workspace Quiescent) and SC-4 (per-host gap) by reference. CRP-331 is pushed.

## 2. Gate 0 Contract

### Target State

`.agents/ACTIVE_SESSION.md` follows one schema. It is written once, as a canonical section of RULE-LCM-030, and every host reads it from there. No host keeps its own copy.

1. **Workspace GoodNight**: only `Invoke-LCM_GoodNight.ps1` sets it. It is stored only as the section 1 `GoodNight Timestamp`, and the section 1 `Status: Quiescent` follows from it. Every host and the script use this value for "Resuming from Good Night at ...".
2. **Host session close**: each host closes its own session by writing only its own block. The status vocabulary is `Active` / `Closed (<ts>)`. A host close never says `Quiescent` or `good-night`.
3. **Snapshot save** (`Saved:` / `Last Updated`): records a save event only. It is never read as a GoodNight.
4. **Gaps**: the workspace gap is measured from item 1. Each host's gap is measured from its own `Last Activity`. Both are reported, each with its label.
5. **Section ownership**: section 1 belongs to the workspace tooling: `Save-AllSessionMemory.ps1` writes `Last Updated`, and with `-Quiescent` also `Status` and `GoodNight Timestamp`; `Invoke-LCM_GoodMorning.ps1` writes `Status: Active (resumed at <ts>; ...)` and `Resumption Timestamp`. In section 2, each host owns its own block. Section 3 is generated from `proposals.db`, or marked "as of <ts>, not live".
6. **Host-block fields**: a fixed list (Status, ID, Last Activity, Current Task, Next Step, Open Operator Decisions, Attention Items). GoodMorning reports all of them. It flags a block whose status is outside the vocabulary, or that is `Active` with a `Last Activity` older than the workspace GoodNight.
7. **DO front-end liveness** (operator 2026-11-17): every good-morning routine checks that the DO front-end (Session 1 daemon on 127.0.0.1:9876, autostart) is running, and starts it if it is not. This covers `Invoke-LCM_GoodMorning.ps1` and every host's good-morning.
8. **Day routines by AI hosts** (operator 2026-11-17, option A): any sanctioned AI host may run `Invoke-LCM_GoodMorning.ps1` and `Invoke-LCM_GoodNight.ps1 [-Push]` on operator instruction. On acceptance of this CRP the following are changed in the same change set (RULE-AUTH-002):
   - RULE-CTX-006: operator exclusivity is removed.
   - RULE-LCM-030 [Claude] annotation and macro table rows `GoodMorning` / `GoodNight`: the operator-only notes are removed.
   - LEARNED_ADVICE Accepted entry "Operator exclusivity for GoodMorning" (2026-11-09): removed, citing CRP-350 (Non-Removal Invariant). Its remaining intent stays binding: GoodMorning is never used as an envelope for baseline or multi-repo research.
   - Claude adapter: WORKPLAN D-26 / D-27 and the `goodmorning` / `goodnight` skills.
   - The Antigravity adapter, where it states the same exclusivity.
9. **No host-exclusive open items** (operator 2026-11-17): while one host is working, every open item is executable by that host. A host may change another host's adapter files (e.g. `GEMINI.md`, `.agents/skills/workspace-governance`) to carry out an accepted CRP. It announces the change in its own block. RULE-LCM-030 (1) is amended accordingly. "No concurrent host work" stays in force.

### Invariants and Exit Criteria

- No concurrent host work. The operator coordinates, and disk wins.
- GoodMorning changes nothing except the item 5 section 1 fields, the item 7 DO start and the Active marker in the running host's own block; with `-WhatIf` it changes nothing.
- AI hosts run the day routines only on operator instruction, never on their own initiative and never on synthetic turns after Quiescent (RULE-LCM-030 (2)).
- Exit 1, handshake A: Claude closes its session, then Antigravity's good-morning runs. Antigravity reports the section 1 GoodNight, reports Claude's close as "Claude closed at ...", and shows both gaps.
- Exit 2, handshake B: Antigravity runs GoodNight, then Claude's `/goodmorning` runs. Claude reports the same GoodNight timestamp as the script and sees Antigravity's block as current.
- Exit 3, negative case: a `learn` call between two sessions shows up as "last save", never as a GoodNight.
- Exit 4: a Claude-run `Invoke-LCM_GoodNight.ps1` and `Invoke-LCM_GoodMorning.ps1` both complete without any rule exception being logged.
- Exit 5: no host block, ACTIVE_CONTEXT section or open bundle task names an item that only one host can perform.
- Parse gate on every changed `.ps1`. Pester for the section-anchored replacements in `Save-AllSessionMemory.ps1`, run against a temp copy and never the live `.agents` files (lesson from BUG-336). BCR / Gate 2 as usual.

### Explicit Non-Goals

- CRP-332 LF delta, CRP-339 compact rule set, DO elevation (CRP-337/343), LEV integration.
- No change to the commit/push gates. GoodNight -Push keeps its review and lockstep checks.
- The default Non-Goal applies: cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Findings (verified 2026-11-17, read-only)

| # | Fact | Evidence |
|:---|:---|:---|
| F1 | Claude `/goodnight` writes the `### Host: Claude Code` block and labels it `Quiescent (good-night <ts>)`. | `LCM_AI/.claude/skills/goodnight/SKILL.md` |
| F2 | `Invoke-LCM_GoodNight.ps1` -> `Save-AllSessionMemory.ps1 -Quiescent` writes the first `- **Status**:` line (section 1) and `GoodNight Timestamp`. It writes no host block. | `Save-AllSessionMemory.ps1`; `Invoke-LCM_GoodNight.ps1` |
| F3 | Three different "GoodNight" sources are in use: the GoodMorning script uses `Saved:` (falling back to the last commit); Claude uses section 1 `GoodNight Timestamp`; Antigravity's reply used Claude's host-block time. | `Invoke-LCM_GoodMorning.ps1`; `goodmorning/SKILL.md` |
| F4 | Every `Save-AllSessionMemory.ps1` call bumps `Saved:` and the section 1 `Last Updated`, including a `learn` call. | `Save-AllSessionMemory.ps1` |
| F5 | "Quiescent" is overloaded: RULE-LCM-030 (2) means the whole workspace, Claude used it per host. | `.agents/rules/ProposalReviewFlowPolicy.md` |
| F6 | The GoodMorning host parser reads only Status, ID, Last Activity, Current Task and Next Step. | `Invoke-LCM_GoodMorning.ps1` |
| F7 | Between GoodNights, nothing owns section 1 or section 3. Claude repaired them by hand on 2026-11-16 and again on 2026-11-17. | `.agents/ACTIVE_SESSION.md` |
| F8 | Nothing writes Antigravity's block mechanically. | F2 |

The open question of what the GoodMorning script printed in Antigravity's 2026-11-17 run is not followed up separately. Exits 1 and 2 test the same behaviour after the fix.

## 4. Absorbed Operator Remarks

- 2026-11-17 (Claude session): "remove the rule that prevents you from calling LCM_goodnight/goodmorning as soon as the convergence of the process has been completed" - answer: option A (this CRP).
- 2026-11-17: "While you are working, there can't be any open items that only Antigravity can perform. We now target for the convergence!"
- 2026-11-17: the good-morning routine must make sure the DO front-end task is running.
