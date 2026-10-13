# Implementation Plan: CRP-265 - Control Hub Rich Action Feedback, Action Consolidation, and Detailed Status Message Area

## 1. UI Message Area Design
1. Add a dedicated, collapsible, rich feedback message banner and log panel to the Control Hub UI.
2. Structure feedback messages with severity levels (INFO, SUCCESS, WARNING, ERROR), timestamp, target tool/action name, and detailed body text.

## 2. Action Consolidation & Layout Optimization
1. **Single Proposal Actions (Top Menu)**: Add missing actions (**retire/withdraw**, **supersede**) to the individual row dropdown menu (`toggleShowDropdown`).
2. **Batch Actions (Bottom Bar)**:
   - Consolidate the two bottom action grids (cohort actions and bulk actions) into a single unified, compact bottom bar to save vertical screen space.
   - Add batch **retire** and **supersede** buttons to the unified bottom bar.
3. **Emergency Override Switches**: Add `Testing OFF` (`testing-mode paused`) radio option to `overrideModal` alongside `-Force` and `-MinimalTests`.

## 3. Backend & Daemon Response Enrichment
1. Extend action execution handlers in `Show-LcmControl.ps1` and daemon bridge endpoints to return structured JSON payloads containing standard exit code, stdout snippet, stderr diagnostic, and human-readable narrative.
2. Wire up client-side dispatch for `withdraw` and `supersede` to prompt for details / target proposal expression when invoked.

## 4. Verification
1. Test action executions (success, warning, error conditions) in ShowCM.
2. Verify retire (`withdraw`) and `supersede` work for both single items (top) and batches (bottom).
3. Confirm unified single bottom bar saves screen space and renders all batch operations cleanly.
4. Validate PowerShell AST and HTML scripts with 0 errors.

