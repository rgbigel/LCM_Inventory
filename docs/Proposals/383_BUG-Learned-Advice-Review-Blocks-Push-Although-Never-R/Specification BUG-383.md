# Specification: BUG-383

Module: docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Specification BUG-383.md  
Purpose: Learned Advice Review Blocks Push Although Never Reviewed  
Path: LCM_Inventory/docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Specification BUG-383.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Suggested  
Date: 2026-11-20 14:52:27

```yaml
CRP-ID: BUG-383
Title: Learned Advice Review Blocks Push Although Never Reviewed
Scope: LCM_Inventory, LCM_AI
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-20 14:52:27
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-20: learned advice is administrative data / an artifact and is never reviewed; the push gate in Invoke-LCM_Push.ps1 (RULE-CTX-005 "review candidates before publish") refused the GoodNight push because one candidate was pending. Target: candidates no longer block a push and need no operator review (accepted by the contributing host); RULE-CTX-005 and the gate changed accordingly (rule change: ADMINMODE, RULE-AUTH-002 sync).
- Review: this Specification only (Plan and Walkthrough not written yet).

### Absorbed Operator Remarks (2026-11-20 GoodMorning discussion)

> The update of Learned_Advice is not updating. This is a MUST requirement, accepted changes must be reflected.
> When this fails, the contradictions must be isolated and brought to attention at the next goodmorning
> processing. [...] DO NOT consider push (or whatever is intended here) is a "publish" of the LCM payload, it is
> just administrative maintenance and part of the backup logic.

Verified state (2026-11-20): the `LEARNED_ADVICE.md` header ("How it works", line 15) still says "A review [...]
happens no later than push: publishing is refused while candidates are pending", i.e. the accepted operator
decision of this BUG is not reflected in the file that carries the advice.

## 2. Gate 0 Contract
### Target State
1. A push (`Invoke-LCM_Push.ps1`, GoodNight `-Push`) is administrative maintenance and backup, not a publication
   of the LCM payload; learned advice (candidates or accepted) never blocks it.
2. Candidates are accepted by the contributing host when written (learned advice is an artifact, no operator review).
3. Every accepted change to the learned-advice regime is reflected in `LEARNED_ADVICE.md` itself (header "How it
   works" and affected entries) in the same change set as the code/rule change (MUST).
4. When reflecting fails or an entry contradicts an accepted decision or rule, the contradiction is isolated
   (entry, conflicting source, since when) and reported by the next GoodMorning as an attention item until resolved.
5. RULE-CTX-005 ("review candidates before publish") and its adapters reworded accordingly (ADMINMODE, RULE-AUTH-002).

### Invariants and Exit Criteria
- Non-Removal Invariant of learned advice preserved; entries change only with CRP citation.
- Tests: push preflight with a pending candidate passes; GoodMorning flags a planted contradiction; header text
  matches the rule.

### Explicit Non-Goals
- No semantic review of the advice content itself.
- Push eligibility (BUG-380 B12) is handled there.

## 3. Acceptance

- 2026-11-20: Specification ACCEPTED by the operator (Rolf) in the Gate 2 review of BUG-380 / BUG-384
  (item 6); DOIT, started after the 10.8.4 push so it does not extend the open review round.
