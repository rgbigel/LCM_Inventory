# CRP-247 Implementation Plan

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-247` |
| **State** | `IN_PROGRESS` |
| **Gate** | Implementation and focused validation in progress |
| **Affected Repository** | `LCM_Inventory` |

## Plan

1. Add a dedicated PowerShell generator for
   `CON-001-L01-R004-S020-CallerIntentReconciliation.json`.
   - Read R004, `forward-index.json`, and `reverse-index.json`.
   - Validate the expected Step 0 baseline and input schemas.
   - Select only unresolved parameter-gate records with at least one published,
     uniquely resolved production caller.
   - Retain source locations, caller symbols, supplied arguments, and
     deterministic confidence/relevance/disposition values.
   - Refuse to overwrite a retained artifact.

2. Extend `Show-LcmAnalysisViewer.ps1`.
   - Accept an optional reconciliation artifact.
   - Render direct, caller-context, total documented, and unresolved metrics.
   - Add caller-context and reconciliation-status filtering.
   - Add a derived-evidence column with source links.
   - Preserve current behavior when no reconciliation artifact is supplied.
   - Replace dropdown filters with tri-state metric buttons: white ignores,
     green includes, and red omits matching records; Functional Elements is
     green-only.
   - Include public-parameter help audit records, enabling Header/Help metric
     buttons to filter the table.
   - Support qualified, grouped search with implicit AND, `AND`/`+`, `OR`/`|`,
     `!`, quoted phrases, and column prefixes.
   - Emit active-editor URI links with source line and column.

3. Update `docs/AnalysisOperations.md`.
   - Document generation, artifact provenance, viewing, and retention.
   - State that Step 2 caller-context coverage is not direct documentation.

4. Validate with the smallest relevant checks.
   - Parse modified PowerShell scripts with the PowerShell parser.
   - Parse generated JSON.
   - Generate the viewer with `-NoLaunch`.
   - Assert the four approved statistics and 23-record scope.

5. Extend the Level 1 branch model.
   - Update the approved definition and Analysis Governance Policy.
   - Generate a distinct record for each `if` and `elseif` clause.
   - Generate an explicit `else` fallback record with no predicate.
   - Generate a new immutable Level 1 run and never alter R004.
   - Defer `try` / `catch` / `finally`, `trap`, and `switch`.

6. Add ADMINMODE rule-change authorization.
   - Initialize hidden state on workspace open from Windows local
     Administrators SID membership without requiring elevation.
   - Provide `Make-Admin -Mode On|Off` for eligible users.
   - Record the current user and SID for initialization, toggles, denials, and
     rule-affecting CRP commit processing.
   - Block staged rule changes when ADMINMODE is disabled.

7. Add complete PowerShell header/help evidence.
   - Keep the requirement under the existing universal script-header rule.
   - Inventory all public script and exported-module-function parameters,
     independently of whether they occur in a parameter gate.
   - Record scoped `.PARAMETER` evidence as the CmdletBinding adapter and
     report missing help separately from branch-gate documentation totals.

## Expected Files

- `tools/Invoke-CallerIntentReconciliation.ps1` (new)
- `tools/Show-LcmAnalysisViewer.ps1` (modified)
- `docs/AnalysisOperations.md` (modified)
- `data/analysis/history/CON-001-L01-R004-S020-CallerIntentReconciliation.json` (new generated evidence)
- `data/analysis/history/CON-001-L01-R005.json` (new generated evidence)
- `LCM_AI/.agents/rules/AnalysisGovernancePolicy.md` (modified)
- `data/analysis/definitions/CON-001-L01.json` (modified)
- `modules/AdminMode.psm1` (new)
- `tools/Initialize-AdminMode.ps1` (new)
- `tools/Make-Admin.ps1` (new)
- `docs/Architecture.md` (modified)
- `Git_Repositories/.vscode/tasks.json` (modified)

## Explicit Non-Actions

- Do not mutate R004.
- Do not change dependency index evidence.
- Do not modify code analyzed by the evidence.
- Do not classify unreferenced code for removal.
- Do not extract error-handling or switch constructs in this CRP.
