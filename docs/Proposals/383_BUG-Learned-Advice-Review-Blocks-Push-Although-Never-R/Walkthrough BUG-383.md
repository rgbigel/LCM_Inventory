# Walkthrough: BUG-383 - Learned Advice Review Blocks Push Although Never Reviewed

Module: docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Walkthrough BUG-383.md  
Purpose: Walkthrough of BUG-383.  
Path: LCM_Inventory/docs/Proposals/383_BUG-Learned-Advice-Review-Blocks-Push-Although-Never-R/Walkthrough BUG-383.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Verified  
Date: 2026-11-20 16:22:49

---

## Path Taken (DOIT, operator 2026-11-20)

- Rule change under ADMINMODE (operator account member of S-1-5-32-544): `LCM_AI/.agents/rules/
  RepositoryContextPolicy.md` 10.3.2, RULE-CTX-005 item 7 "No Review Gate" (learned advice is administrative
  data, accepted by the contributing host, never blocks a push; a push is maintenance and backup) and new item 9
  "Reflection & Contradictions".
- RULE-AUTH-002 sync: Claude adapter `LCM_AI/.claude/rules/process/RepositoryContextPolicy.md` (RULE-CTX-005
  line), `LCM_AI/.claude/translation/CANONICAL_HASHES.md` (re-hash); `AGENTS.md` quick reference and
  `LCM-Rules-Cross-Reference.md` carry no CTX-005 detail (rule ID row unchanged).
- `LCM_AI/.agents/LEARNED_ADVICE.md`: header follows the accepted decision (no review gate; reflection;
  contradiction marker); the entry "keep CRLF/BOM" is marked `[CONTRADICTS: InvariantRules newline-lf and
  utf8-without-bom (BUG-365)]` (marked, not removed).
- `LCM_AI/.agents/ACTIVE_CONTEXT.md`: RULE-CTX-005 quick line.
- `LCM_Inventory/tools/Invoke-LCM_Push.ps1` 10.2.8: the learned-advice gate is removed.
- `LCM_Inventory/tools/Invoke-LCM_GoodMorning.ps1` 10.2.7: pending candidates are no push condition; every entry
  that starts with the marker is reported as an attention item (the header that explains the syntax does not
  count: found in the first check and corrected).
- Not changed: `Save-AllSessionMemory.ps1 -Learn` still writes a candidate; the contributing host accepts it right
  away (`Invoke-LearnedAdviceReview.ps1 -Accept`).

## Test Evidence (2026-11-20 16:22:49)

| Check | Result |
|:---|:---|
| `Parser::ParseInput` push, GoodMorning | 0 errors |
| `Invoke-LCM_GoodMorning.ps1 -Force -NoBaseline -WhatIf` | one contradiction reported (the CRLF/BOM entry, source BUG-365); 0 candidates |
| `Invoke-LCM_Push.ps1 -DryRun -NonInteractive` | runs without the learned-advice gate; exit 0 |
