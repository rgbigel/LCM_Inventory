# CRP-198: RollingCalendar — New Repository Integration

Module: Workspace_Inventory/docs/Proposals/CRP-198-RollingCalendar-New-Repository-Integration/Specification.md
Purpose: Integrate the RollingCalendar PowerShell script as a new LCM-governed repository with full tripartite documentation, install runbook, and governance wiring.
Path: Workspace_Inventory/docs/Proposals/CRP-198-RollingCalendar-New-Repository-Integration/Specification.md
Authors: rgbig, Workspace_AI Governance
Version: 8.1.1
Status: Verification — Interface Refinement Reviewed
Date: 2026-09-30

---

## Metadata

| Field | Value |
|:---|:---|
| **CRP-ID** | CRP-198 |
| **Title** | RollingCalendar — New Repository Integration |
| **Target Scope** | New repository `RollingCalendar` under `D:\Git_Repositories\` |
| **Affected Version Range** | v1.0.0 (initial) |
| **Impacted Repositories** | `RollingCalendar` (new), `Workspace_Inventory` (ledger) |
| **App Context** | App: 1 (active context at intake) |
| **Priority** | M |

---

## 1. Problem Statement

A PowerShell script (`Invoke-RollingCalendar.ps1`) was authored to render a rolling
Outlook ICS calendar as a DIN A4 landscape PDF via Microsoft Edge Headless. The script
was onboarded as a first-class LCM-governed repository with proper governance wiring,
tripartite documentation, and install runbook. All user-facing strings were translated
from German to English per `LANGUAGE-POLICY`.

---

## 2. Requirements

### Functional
- Repository `D:\Git_Repositories\RollingCalendar` initialized as a Git repository.
- Script corrected and placed at `Invoke-RollingCalendar.ps1` (repository root).
- `output\` directory excluded via `.gitignore`.
- Temporary `temp_calendar.html` excluded via `.gitignore`.
- Capture Edge process output and suppress only known non-fatal Chromium
  renderer diagnostics after a successful PDF creation, while reporting nonzero
  exits, missing/empty PDFs, and all other stderr output as actionable failures
  or warnings.
- Accept the workspace timestamp conventions `yyyyMMdd_HHmm` and
  `yyyyMMdd_HHmmss`, as well as the existing `HH:mm` and `HHmm` schedule-time
  formats, normalizing each to the Task Scheduler time of day.
- Provide `-o` as an unambiguous alias for the output-directory parameter. A
  supplied directory such as `-o C:\Temp` receives the normal generated filename
  (`Calendar_<N>W_<yyyy-MM-dd>.pdf`). `-NoShow` replaces `-OpenAfterExport` and
  defaults to `$false`, so the generated PDF opens unless explicitly suppressed.
- Set the default output directory to `C:\Temp`, retaining the generated
	filename format `Calendar_<N>W_<yyyy-MM-dd>.pdf` when no output directory is
	supplied.

### Governance
- `.agents/rules` NTFS junction pointing to `Workspace_AI\.agents\rules`.
- `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` at script top.
- Advanced script and function declarations with explicit function inputs.
- Focused Pester structural quality tests before the review gate.
- Automated Beyond Compare review staging against the committed baseline.
- DOX header added to script.
- 2-space indentation enforced throughout.
- All German strings translated to English per `LANGUAGE-POLICY`.
- ASCII-safe `'>> '` display prefix replacing Unicode arrow character.
- CRLF line endings, UTF-8 without BOM.

### Documentation (RULE-DOC-001)
- `docs/Architecture.md` — operator mental model, CLI entry points, PDF output topology.
- `docs/Requirements.md` — prerequisites, normative invariants, error handling.
- `docs/Implementation.md` — script inventory, parameter signatures, constituent manifest.
- `README.md` — executive summary linking tripartite specs.

### Install (RULE-DOC-004)
- `install/Installation.md` — 7-phase runbook.

---

## 3. Script Corrections Applied

| # | Rule | Issue | Resolution |
|---|:---|:---|:---|
| 1 | RULE-PS-005 | `$ErrorActionPreference` on same line as previous statement | Split to dedicated line |
| 2 | RULE-PS-005 | Missing `Set-StrictMode -Version Latest` | Added after params block |
| 3 | INVARIANT indent-2 | 4-space indentation throughout | Normalized to 2-space |
| 4 | RULE-DOC-003 | No DOX header | Added standard DOX header |
| 5 | LANGUAGE-POLICY | All German user-facing strings | Translated to English |
| 6 | INVARIANT ascii-default | Unicode arrow `U+2B8E` in PS string | Replaced with ASCII `'>> '` |
| 7 | INVARIANT newline-crlf | Mixed LF/CRLF in source | Normalized to CRLF on disk |
