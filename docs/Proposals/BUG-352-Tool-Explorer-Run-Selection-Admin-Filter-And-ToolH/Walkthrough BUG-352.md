# Walkthrough: BUG-352 - Tool Explorer Run Selection Admin Filter And ToolHelp Fail

Date: 2026-11-18 18:19:05

## 1. Path taken and issues on the way
- ToolHelp: the old fallback captured `2>&1`; for `Invoke-LCM_Maintenance.ps1` that produced 0 characters (its help is `Write-Host` output), the new `*>&1` capture 1163 characters - this is why help files were empty.
- The help window uses Notepad++ (`-multiInst`, a new foreground window) instead of Windows 11 Notepad, which opened a background tab in an existing non-elevated window.
- The synthetic-cohort completion now completes the head item across all changed governed repositories; before it accepted one repository obligation. This follows the BUG-351 completion model (obligations are resolved inside the completion).
- `Complete-ReviewCohort.ps1` still has the other defects found by the analysis (empty validation loop, unused parameter, no DOX header); left for CRP-357.

## 2. Verification evidence (2026-11-18 16:01:00)
- `node --check`: `lcm-tool-explorer.js` OK; Control Hub inline scripts 1 and 3 OK (2 is the JSON data block).
- Parse gate: `Submit-ReviewResult.ps1`, `Invoke-ProposalAction.ps1`, `Complete-ReviewCohort.ps1`, `LcmReviewCompletionAtoms.psm1`, `ProposalCompletion.Tests.ps1` 0 errors.
- `tests/ProposalCompletion.Tests.ps1`: 7 passed, 0 failed (with the shared atom).
- `Show-LcmControl.ps1 -NoLaunch`: rendered cleanly.
- Operator browser tests pending: Run Selection with parameters (e.g. `Apply-AllCustomizations.ps1 -StartAt 0 -ShowAll`), Admin filter values, ToolHelp, Control Hub "reviewed".

## Scope note (2026-11-18 18:19:05)

- The Admin filter fix repairs only the value mismatch (dropdown `true`/`false` against `Admin`/`User`). The tri-state privilege (1 = none, 2 = controlled, 3 = admin) with its labels and the border enforcement is not part of BUG-352; it is CRP-343 section 9 (delivery: section 9.6).
