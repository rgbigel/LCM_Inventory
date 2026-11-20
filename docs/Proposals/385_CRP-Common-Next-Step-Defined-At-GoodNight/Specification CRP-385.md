# Specification: CRP-385

Module: docs/Proposals/385_CRP-Common-Next-Step-Defined-At-GoodNight/Specification CRP-385.md  
Purpose: Common Next Step Defined At GoodNight  
Path: LCM_Inventory/docs/Proposals/385_CRP-Common-Next-Step-Defined-At-GoodNight/Specification CRP-385.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 12:01:10

```yaml
CRP-ID: CRP-385
Title: Common Next Step Defined At GoodNight
Scope: LCM_Inventory, LCM_AI
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-20 12:01:10
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator 2026-11-20:

> There is no next step for ANTIGRAVITY, remove any such description it could be using without my permission.
> The Next Step and that of Antigravity should be common and current, and defined at GoodNight. It should be
> picked up by the first Agent that does the next GoodMorning task, with a ticket that the other agent can absorb.

Today every host block in `.agents/ACTIVE_SESSION.md` carries its own "Next Step". The Antigravity block held a
step Claude had written (2026-11-17) that Antigravity could have acted on without operator permission (removed
2026-11-20 on operator instruction). Host-private next steps drift apart and contradict the convergence target
"no open item may be executable only by one host" (CRP-350 item 9, D-38).

- Review: this Specification only.

## 2. Gate 0 Contract

### Target State

1. `ACTIVE_SESSION.md` section 1 holds ONE workspace Next Step (current, with the ticket ID that carries it).
2. The Next Step is defined at GoodNight (operator states it, or confirms the proposal of the closing host);
   `Invoke-LCM_GoodNight.ps1` writes it to section 1.
3. Every Next Step is a ticket (CRP / BUG in `proposals.db`); a step without a ticket is not written.
4. The first host running the next GoodMorning picks it up, states it in its first reply and records itself as
   the working host in its block; the other host absorbs the ticket by its ID when it is next active.
5. Host blocks keep Status, ID, Last Activity, Current Task, Open Operator Decisions, Attention Items; their
   "Next Step" field is retired (RULE-LCM-030 (5) field list changes: rule change, ADMINMODE, RULE-AUTH-002 sync).
6. GoodMorning reports the common Next Step and flags any host block that still carries its own next step.

### Invariants and Exit Criteria

- No AI host acts on a next step the operator has not stated or confirmed.
- Test: GoodNight with a stated step writes section 1; GoodMorning (Claude and Antigravity) reports it; a host
  block with a private next step is flagged.

### Explicit Non-Goals

- No automatic execution of the Next Step at GoodMorning (the host still waits for operator direction).
- No change to the proposal lifecycle.
