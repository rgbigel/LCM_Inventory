# Change Request Proposal: CRP-164

```yaml
CRP-ID: CRP-164
Title: Usability Improvements & Interactive Document Viewer Optimization
Scope: LCM Governance, CM Control Hub, Documentation Review Engine & Tools Catalog
Baseline-Version: 10.0.0
Author: Rolf, LCM_AI Engine
Date: 2026-10-13
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: High
Impacted-Repositories:
  - LCM_Inventory
  - .lcm
  - LCM_AI
```

---

## 1. Executive Summary & Problem Context

During operational testing of the **Repository Documentation Table** (`📚 Repository Documentation Table: .lcm`) and **CM Control Hub Tooling Hub**, a set of 13 usability defects, display formatting issues, and naming inconsistencies were identified:

1. **Document Duplication**: Documents with/without `docs/` prefix are listed twice (e.g., 6 rows instead of 3 for Architecture, Requirements, Implementation).
2. **Missing Formatted Preview & LF vs CRLF**: Clicking a document row or the "Show" action fails to render a formatted preview with proper paragraph structure due to raw LF line-ending handling.
3. **Show Action Functionality**: "Show" action does not open the formatted preview pane.
4. **Edit Action Failure & Orphaned CMD Windows**: Clicking "Edit" or "Open All in Notepad++" opens multiple non-closing CMD console windows, throws `showToast is not defined`, and lacks native VS Code integration.
5. **Column Sizing & Awkward Line Wrapping**: "Review State" column is too narrow causing `AUTHORITATIV_E` to split across lines, while "Timestamp" is unnecessarily wide.
6. **Selection Button Labeling**: Batch open button says "Open All in Notepad++" regardless of selection.
7. **Redundant Bottom Buttons**: Bottom Print button is broken and redundant with header "🖨️ Print / Save PDF", and bottom Close button is redundant with header "⬅️ Back".
8. **Role Filtering Defects**: Filtering by "Overview (README)" or "All Roles" omits `README.md`.
9. **Headline & Filter Pinning**: Table headers, search filters, and toolbars scroll away with payload instead of remaining sticky at the top.
10. **Tools Catalog Roles & Audience**: Tool roles lack a clear `Dev/Internal` classification distinct from `User`/`Operational`.
11. **Zero-Parameter Default Invariant**: Tools run from dashboard/CLI (e.g., `Show-WorkspaceReadiness`) require manual parameters instead of defaulting intelligently to current context.
12. **`Show*` Naming Invariant**: Cmdlets with `Show-` prefix must always produce visual table/HTML displays; non-display internal utilities should use `Determine-`, `Get-`, `Test-`.
13. **Tool Deduplication & Renaming**:
    - `Show-CrpDates.ps1` $\rightarrow$ Consolidate to `Show-CRPs.ps1`.
    - `Show-ToolIndex.ps1` vs `Show-Tools.ps1` $\rightarrow$ Consolidate into authoritative `Show-Tools.ps1`.
    - `Show-WorkspaceInventoryApp.ps1` $\rightarrow$ Rename to `Show-Inventory.ps1` and reclassify from `Dev` to `User/Operational`.

**`CRP-164`** unifies these 13 items into an authoritative, cohesive batch usability upgrade.

---

## 2. Technical Requirements & Architectural Invariants

### Invariant 1: Document Deduplication & Canonical Keys
In `openRepoDocsReview(repoStr)`:
- Normalize cached keys by basename/canonical relative path (`docs/<DocName>.md`).
- Deduplicate document lists so every unique document in a repository appears exactly once.

### Invariant 2: High-Fidelity Formatted Markdown Preview
- Use robust Markdown rendering in `formatMarkdown()` supporting CRLF/LF paragraph normalization, headers, tables, code blocks, and blockquotes.
- Clicking a document row or "🔍 Show" action opens formatted preview in the inspection modal or preview pane.

### Invariant 3: Clean Editor Dispatch (VS Code Integration)
- Replace broken Notepad++ CMD spawn with clean VS Code editor dispatch (`code -g <filePath>` / `vscode://file/<path>` / daemon IPC) with zero lingering CMD windows.
- Dynamically label action: "✏️ Open Selected in VS Code" (or "Open All in VS Code" when none selected).
- Fix `showToast` scope and error handling.

### Invariant 4: Layout & Visual Hierarchy Standards
- Pin modal headers, search bars, filter dropdowns, and column headers with `position: sticky; top: 0; z-index: 10;`.
- Set Review State column `min-width: 140px;` with `white-space: nowrap;` to prevent `AUTHORITATIVE` wrapping.
- Tighten Timestamp column to `120px`.
- Remove redundant bottom Print and Close buttons.

### Invariant 5: Tooling Governance & Zero-Parameter Defaults
- **`Show*` Prefix Standard**: Any script with `Show-` `MUST` output an interactive HTML or formatted table display. Non-display utilities `MUST` use `Determine-`, `Get-`, `Test-`, or `Resolve-`.
- **Zero-Parameter Invariant**: Dashboard/CLI tools `MUST` execute with zero required parameters, defaulting intelligently to the active repository or full workspace.
- **Audience Hierarchy**: Categorize tools cleanly into `User`, `Operational`, `Governance`, and `Dev/Internal`.
- Consolidate:
  - `Show-CrpDates.ps1` $\rightarrow$ `Show-CRPs.ps1`
  - `Show-ToolIndex.ps1` $\rightarrow$ `Show-Tools.ps1`
  - `Show-WorkspaceInventoryApp.ps1` $\rightarrow$ `Show-Inventory.ps1` (Audience: `User/Operational`)

---

## 3. Component Architecture & Affected Files

```text
LCM_Inventory/
├── docs/
│   └── Proposals/
│       └── CRP-164-LCM-10.0.0-Usability-Improvements-And-Document-Viewer-Optimization/
│           ├── Specification.md
│           ├── Implementation_Plan.md
│           └── Walkthrough.md
├── assets/
│   ├── CM_CONTROL_HUB.html         # Document viewer fixes, sticky headers, VS Code dispatch, column sizing
│   └── LCM_SIDECAR.html            # Companion Actions Sidecar dashboard
├── tools/
│   ├── Show-CmControlHub.ps1       # Compatibility forwarder
│   ├── Show-LcmControl.ps1         # Unified Hub & Sidecar browser dispatcher
│   ├── Show-LcmSidecar.ps1         # Companion Sidecar launcher
│   ├── Show-CRPs.ps1               # Consolidated from Show-CrpDates.ps1
│   ├── Show-Inventory.ps1          # Renamed from Show-WorkspaceInventoryApp.ps1 with 0-param defaults
│   └── Show-WorkspaceReadiness.ps1 # Intelligent default to current repo
LCM_Inventory/
├── config/
│   └── tool_catalog.json           # Updated role/audience classifications and renamed tools
└── Cmd/
    └── ShowTools.cmd               # Updated tool dispatchers
```

---

## 4. Retrospective Architectural Amendment: Hub & Sidecar Unified Single-Window Launch

### Problem & Defect in Initial Implementation:
The original implementation in `tools/Show-LcmControl.ps1` and `tools/Show-LcmSidecar.ps1` forced Microsoft Edge `--app` mode into two separate standalone popup windows at fixed pixel coordinates (`--window-position=30,30` and `1310,30`). This violated core operational ergonomics:
1. **Detached Companion Contradiction**: A "Sidecar" is an attached companion to the Hub vehicle, not an independent floating application that clutters the desktop and taskbar.
2. **Forced Microsoft Edge**: It ignored the operator's primary browser (**Zen Browser / Firefox**).
3. **Precluded Native Split View**: In Zen Browser and Firefox, tabs in the same window can be natively split side-by-side with a single click, providing the ideal sidecar experience within a single application window frame.

### Corrected Specification Invariant:
1. **Dynamic User Default Browser Resolution**:
   - `Show-LcmControl.ps1` and `Show-LcmSidecar.ps1` **MUST** dynamically detect the operator's configured default browser from the Windows Registry (`HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice` $\rightarrow$ `ProgId` $\rightarrow$ `shell\open\command`). No personal browser preference is hardcoded.
2. **Layout Adaptation Strategy**:
   - **Modern Split-Tab Browsers (Zen Browser, Firefox)**:
     - The tool launches the Hub (`CM_CONTROL_HUB.html`) and Sidecar (`LCM_SIDECAR.html`) as **two tabs in a single browser window** (primary URL followed by `--new-tab <sidecarUri>`), enabling immediate native Split View side-by-side inside the browser window.
   - **Chromium / Edge / Non-Split Browsers (Microsoft Edge, Google Chrome, Brave)**:
     - For browsers that do not natively feature vertical split tabs, the tool launches **two windows stacked vertically (one above the other)**:
       - **Top Window (Control Hub)**: `--new-window "<launchTarget>" --window-position=30,20 --window-size=1860,540`
       - **Bottom Window (Actions Sidecar)**: `--new-window "<sidecarUri>" --window-position=30,575 --window-size=1860,450`
3. **Ergonomic Invariant**:
   - Forced `--app` chromeless popups and detached desktop floating windows are strictly retired in favor of browser-native tabbed or stacked window ergonomics.
