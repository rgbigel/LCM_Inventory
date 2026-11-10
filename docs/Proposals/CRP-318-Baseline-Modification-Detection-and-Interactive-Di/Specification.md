# Change Request Proposal: CRP-318

```yaml
CRP-ID: CRP-318
Title: Baseline Modification Detection and Interactive Dismount Choice Guardrail
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-11-10 20:27:20
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 8
App-ID: None
```

---

## 1. Executive Summary & Intent
Before detaching or replacing an active Macrium BCR baseline (or simulated sandbox drive), detect whether the mounted baseline contents have been modified or contain review markers. If modifications are detected, issue a clear warning detailing the changes and provide the operator with an interactive choice (`[Y] Dismount and discard changes / [N] Cancel`), while supporting an explicit `-Force` / `-DiscardChanges` switch for automated or intentional overrides.

---

## 2. Gate 0 Contract

### Target State
1. **Pre-Dismount Content Audit**: Before unmounting candidate drives (`F` through `I`), scan for modified, added, or deleted files in git-tracked repositories on the mounted drive.
2. **Interactive Operator Choice**: If changes are detected and `-Force` is not specified:
   - In interactive sessions: Prompt the user with details of detected changes and request confirmation to proceed.
   - In non-interactive sessions: Abort with code 1 and advice to specify `-Force` to prevent accidental data/marker loss.
3. **Sandbox Preservation**: Safeguards in-flight LHS review progress markers and simulated sandbox workspace modifications from accidental destruction.

### Invariants and Exit Criteria
- **Choice Invariant**: The operator is never locked out from dismounting when they intend to (e.g. when a fresh backup is ready), but accidental unmounts of modified baseline drives are prevented.
- **Auditing Invariant**: Warning explicitly identifies the repository and count of modified/untracked files detected on the baseline.
- **Pass-through**: Dismounting an unmodified baseline proceeds without interruption.

### Explicit Non-Goals
- Modifying Macrium backup creation itself.
- Blocking dismounts when the operator explicitly provides consent or passes `-Force`.

---

## 3. Technical Requirements & Invariants
- Add `Test-LcmBaselineModifications` atom in `LCM_Inventory/modules/LcmMacriumAtoms.psm1`.
- Update `Dismount-MacriumCurrentBaseline.ps1` to invoke modification detection before issuing the unmount command, warning the operator and prompting for choice unless `-Force` is supplied.
- Codify `RULE-REV-013` in `ReviewCommitGovernancePolicy.md` and update `AGENTS.md` and `LEARNED_ADVICE.md`.
