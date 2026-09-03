# CRP-2026-048-LCM-UI-Template-Standardization

## 1. Proposal Identity
- **CRP ID:** CRP-2026-048
- **Title:** Universal LCM Browser Table UI/UX Standard Template Extraction
- **Domain:** Global Workspace UI/UX
- **State:** `DEFERRED`
- **Target Repository:** `Workspace_Inventory`
- **Lead Architect:** LCM Framework

## 2. Rationale & Problem Statement
Currently, all interactive dashboards (Tool Explorer, Workspace Inventory Viewer, CM Control Hub, Supervision Hub, Show-LCMRules, Show-Subsystems) duplicate significant amounts of HTML/CSS/JS scaffolding to achieve the standard LCM dark-mode aesthetic (vibrant colors, table hover effects, sticky headers, modals, filtering logic). 

Extracting this common structure into a formal, unified template engine (e.g., a `.psm1` HTML generator or a standard `.html` base template injected dynamically) will drastically reduce maintenance overhead and ensure UI consistency across all future tools.

## 3. Proposal Details
1. **Analyze existing table displays** across all active Hubs to isolate common CSS variables, core scripts (`applyTheme`, `showToast`, `sortTable`), and structural layout (`<header>`, `<main class="table-container">`, `<div class="action-btns">`).
2. **Abstract into `LcmUiEngine.psm1`**: Create a central module that handles the rendering of standardized frames, injecting page-specific column definitions and JSON datasets.
3. **Refactor existing hubs**: Migrate all current `Show-*` scripts to utilize the new template generator rather than injecting raw HTML payloads.

## 4. Rollback & State
This CRP is held in the `DEFERRED` state as the current objective prioritizes delivering functional dashboards (like `Show-LCM.ps1`, `Show-LCMRules`, `Show-Subsystems`) over immediate technical debt reduction. It will be scheduled for a future architectural sprint.
