# Implementation Plan: BUG-352 - Tool Explorer Run Selection Admin Filter And ToolHelp Fail

Date: 2026-11-18 16:01:00

## Changes per file
- `assets/lcm-tool-explorer.js` (10.0.1 -> 10.0.2): new `buildToolCommandFromParams(tool, dict)`; `command` added to both DO requests (configured run, run with saved parameters); `matchAdmin` accepts `true` / `false`; `openToolHelp` writes `& <tool> -h *>&1` to `scratch/help_<tool>.txt` and opens it with `notepad++.exe -multiInst -nosession`; `fallbackToolHelp` and the `/tool_help` call removed.
- `modules/LcmReviewCompletionAtoms.psm1` (new): `Test-LcmBcrExcludedPath`.
- `tools/Submit-ReviewResult.ps1` (10.2.3 -> 10.2.4), `tools/Invoke-ProposalAction.ps1` (10.2.4 -> 10.2.5): import the atom, local copies removed; `tools/Complete-ReviewCohort.ps1`: dead copy removed.
- `assets/CM_CONTROL_HUB.html`: synthetic-cohort complete and "reviewed" route to `Invoke-ProposalAction -Action complete` (head item / first selected item).
- `tests/ProposalCompletion.Tests.ps1`: imports the atom.