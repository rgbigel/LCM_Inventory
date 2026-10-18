# Change Request Proposal: CRP-278

`yaml
CRP-ID: CRP-278
Title: GoodNIGHT Save-All Receipt and GoodMorning Recovery Gate
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-15 16:26:46
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: High
App-ID: None
`

---

## 1. Executive Summary & Intent
Provide durable evidence that GoodNIGHT completed IDE Save All and require
GoodMorning to surface actionable recovery guidance when the evidence is absent
or incomplete.

## 2. Technical Requirements & Invariants

- A GoodNIGHT receipt is written only after the operator acknowledges IDE Save
  All completion.
- The receipt records its completion time and enough session identity to avoid
  confusing an old receipt with the current working session.
- GoodMorning reads the receipt without changing it.
- When the receipt is absent, stale, or incomplete, GoodMorning reports a
  blocking, actionable reminder before it reports the session ready.
- The new receipt must not replace `ACTIVE_CONTEXT.md`, `LEARNED_ADVICE.md`,
  or the existing Save-All session-memory behavior.
- The implementation must preserve the read-only default behavior of
  `Invoke-WorkspaceGoodMorning.ps1`.

## 3. Delivered Contract

- The receipt is stored at
  `LCM_Inventory\data\session_state\goodnight-saveall-receipt.json`.
- `Invoke-WorkspaceGoodNight.ps1` writes it only with
  `-SaveAllConfirmed`, after its session-memory snapshot succeeds.
- The receipt records schema version, completion state, completion time,
  workspace identity, confirmation identity, session identity, and the
  snapshot timestamp.
- GoodMorning classifies a receipt as `valid`, `missing`, `malformed`,
  `incomplete`, `mismatched`, or `stale`. Any non-valid state is an
  actionable recovery block and prevents `-Auto` from silently returning.

## 4. Verification Requirements

- Test receipt creation only after an explicit Save All acknowledgement.
- Test missing, stale, and malformed receipt handling.
- Test that GoodMorning reports the recovery reminder and does not silently
  treat missing receipt data as success.
- Run focused PowerShell AST validation and the repository readiness gate.
