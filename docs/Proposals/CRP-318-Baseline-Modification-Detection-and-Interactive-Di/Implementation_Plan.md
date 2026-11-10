# Implementation Plan: CRP-318 - Baseline Modification Detection and Interactive Dismount Choice Guardrail

## 1. Executive Summary & Problem Context
Before detaching or replacing an active Macrium BCR baseline drive, detect if any repository contents or review markers have been modified on the mounted volume. If detected, warn the operator with details and offer an interactive choice to discard or cancel, supporting `-Force` for intentional bypass.

## 2. Gate 0 Traceability
- **Detection Function**: `Test-LcmBaselineModifications` in `LcmMacriumAtoms.psm1` checks `git status --porcelain` on the mounted baseline drive repositories.
- **Interactive Choice**: `Dismount-MacriumCurrentBaseline.ps1` issues a structured warning and asks the operator `[Y/N]` if running interactively.
- **Automated / Explicit Bypass**: `-Force` switch allows callers to bypass the confirmation when intentional.
- **Governance**: Formalized as `RULE-REV-013` in `ReviewCommitGovernancePolicy.md`.

## 3. Proposed Changes
### Component 1: `LcmMacriumAtoms.psm1`
- Export `Test-LcmBaselineModifications` function:
  - Takes `-CandidateDrives` (or auto-discovers mounted baseline drive).
  - Inspects child repositories under `<MountedDrive>\Git_Repositories` (or `<MountedDrive>\*`).
  - Returns structured object with `$HasModifications`, `$ModifiedRepositories`, `$FileCount`.

### Component 2: `Dismount-MacriumCurrentBaseline.ps1`
- Add `-Force` switch (`[switch]$Force`).
- Before invoking unmount, call `Test-LcmBaselineModifications`.
- If modifications are detected:
  - If `-Force` is present: Proceed with warning log.
  - If interactive (`[Environment]::UserInteractive`): Prompt `$host.UI.PromptForChoice(...)` with `[Y] Proceed and discard / [N] Cancel`.
  - If non-interactive without `-Force`: Throw error instructing operator to provide `-Force` or consent.

### Component 3: Governance Policy Update
- Add `RULE-REV-013` to `LCM_AI/.agents/rules/ReviewCommitGovernancePolicy.md`.
- Update `AGENTS.md`, `LCM-Rules-Cross-Reference.md`, and `LEARNED_ADVICE.md`.

## 4. Verification Plan
- Unit tests in `tests/BaselineModifications.Tests.ps1`:
  - Verify detection of untracked and modified files on a test baseline path.
  - Verify that unmodified baseline proceeds without prompt.
  - Verify that `-Force` bypasses prompt.
- General LCM quality gates verification.
