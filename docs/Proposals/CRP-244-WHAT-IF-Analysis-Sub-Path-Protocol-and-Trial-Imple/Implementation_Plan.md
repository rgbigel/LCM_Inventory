# Implementation Plan: CRP-244 - WHAT-IF Analysis Sub-Path Protocol and Trial Implementation Branching

## 1. Executive Summary & Problem Context
Enables safe, non-destructive hypothesis evaluation when a CRP faces design uncertainty or implementation hurdles. By providing atomic pre-trial checkpointing, an isolated `TRIAL_IMPLEMENTATION` state, and dual-disposition resolution (promote on accept, rollback to pre-trial state on reject), this protocol enables agile exploration without baseline corruption.

---

## 2. Proposed Changes & Work Breakdown

### Phase 1: Governance Rules & Policy Extension (`LCM_AI/.agents/rules/`)
- Extend [`AnalysisGovernancePolicy.md`](file:///D:/Git_Repositories/LCM_AI/.agents/rules/AnalysisGovernancePolicy.md):
  - Add **`RULE-ANA-007` (WHAT-IF Sub-Path Protocol & Rollback Invariant)**:
    - Pre-trial snapshot capture requirement.
    - Prohibition of direct Git commits while in `TRIAL_IMPLEMENTATION`.
    - Mandatory 100% rollback fidelity upon review rejection.
    - Immediate mode reset to `READ_ONLY_ANALYSIS` on rejection.

### Phase 2: Engine Checkpoint & Restoration Commands (`LCM_Inventory/modules/`)
- In `AnalysisGovernance.psm1`:
  - `New-LcmWhatIfSnapshot -ProposalId <ID> -Hypothesis <Text>`
  - `Restore-LcmWhatIfSnapshot -ProposalId <ID>`
  - `Promote-LcmWhatIfTrial -ProposalId <ID>`
  - Add `what_if_active`, `what_if_parent`, and `what_if_hypothesis` to session state schema.

### Phase 3: CLI & Control Hub Integration (`LCM_Inventory`)
- In `Invoke-ProposalAction.ps1`:
  - Add `-Action what-if`, `-Action rollback-trial`, `-Action promote-trial`.
- In `CM_CONTROL_HUB.html`:
  - Display active `WHAT-IF` banner/pill when active.
  - Add quick action: "Discard Trial & Restore Analysis".

---

## 3. Verification & Quality Gates
- Pester unit tests validating snapshot creation, file modifications during trial, and flawless restoration of pre-trial state upon `Restore-LcmWhatIfSnapshot`.
- Verification that rejection returns session to `READ_ONLY_ANALYSIS`.
