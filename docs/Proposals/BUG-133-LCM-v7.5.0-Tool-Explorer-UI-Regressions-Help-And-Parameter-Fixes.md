---
Bug-ID: BUG-133
Scope: LCM
Version: v7.5.0
Affected-Repos: [LCM, Workspace_AI, Workspace_Inventory]
Severity: High
Status: ACCEPTED
Date: 2026-09-10
Author: Operator Directive / Bug Intake
Root-Cause: Hardcoded title version strings in LcmToolCatalog, unparameterized smart-run defaults in lcm-tool-explorer.js, .lnk path resolution failure in help dispatcher, missing Help (-h) parameter in Advance-Governance.ps1, legacy LCD catalog residue, broken relative scratch back link, and missing parameter descriptions in Invoke-BeyondCompareReview.
---

# BUG-133: LCM Tool Explorer UI Regressions, Parameter/Help Execution Defects, and Navigation Fixes

## 1. Issue Summary
The operator reported 11 defects, functional discrepancies, and UX enhancements across the LCM Tool Explorer dashboard (`SHOW_TOOLS.html`, `LcmToolCatalog.psm1`, `lcm-tool-explorer.js`) and associated governed tools:
1. **Stale Version Display across Standard Displays**: Header and title display `V6.1.0` despite numerous updates. This defect impacts not only `LcmToolCatalog.psm1` / `SHOW_TOOLS.html`, but all `Show-*` (Standard Display) items. Where possible, standard versioning and header layouts should be centralized and styled via CSS (`StandardTableDisplay.css`).
2. **Hardcoded Subsystem Metric Card**: The metric card for `HaSSD06` is static; it should dynamically reflect the Subsystem selected in the dropdown (or clicking it should be a safe No-OP rather than forcing HaSSD06).
3. **Over-Aggressive Parameter Prompting**: Clicking a tool name always opens the parameter modal dialog, even when a tool has no required parameters or no parameters at all (e.g. `@06-Configure_Easy_Context_Menu`). Parameter modal should only appear when a required, non-defaulted value is missing.
4. **Command Console Non-Auto-Closing**: For actions in the three-dot dropdown, console windows remain open even when the tool is configured as `May Exit` (NoExit = false).
5. **Static Tool Script Resolution & Notepad Help Viewer**: Invoking tool help (-h) opens a visible console terminal instead of opening the synopsis/help in `notepad.exe`. Finding the underlying `.ps1` file `MUST NOT` evaluate `.lnk` shortcuts on disk; it must resolve statically from the LCM catalog data (`tool.RelativePath`).
6. **Missing Refresh Button**: The on-screen Refresh button is missing from the toolbar (required for Standard Display compliance).
7. **Phantom `LCD` Subsystem**: The Subsystem dropdown retains legacy `LCD` entry; subsystems list needs authoritative discovery from governed repositories.
8. **Broken Back Navigation**: The "Back" button attempts to open `../scratch/SHOW_LCM.html` which does not exist.
9. **Universal CLI Help Audit & Enforcement Across All Tools**: Invoking help on `AdvanceGovernance` fails with `Advance-Governance.ps1: A parameter cannot be found that matches parameter name 'h'`. This defect must be generalized: audit and enforce that all governed LCM tool scripts implement `[Alias('h', '?')][switch]$Help` per `RULE-PS-010`.
10. **Parameter Descriptions & CRP-134 Alignment**: In `Invoke-BeyondCompareReview.ps1` (and all tools), parameters without descriptions must define `HelpMessage` attributes and `.PARAMETER` docblocks. With `CRP-134` accepted, `-BeyondComparePath` is de-parameterized into an environment constant.
11. **Negative ("NOT") Filtering via Structured Global Search (Alternative B)**: Adopt Alternative B: support structured query tokens in the global search input (e.g. `!Audience:dev`, `!Group:LCM`, `!Env:CMD`) to filter out matching rows.
12. **Interactive Filter Presets Dropdown & User Preset Engine**: Add a preset selector dropdown to switch between standard view configurations (e.g. *Default*, *LCM Core*, *General Non-LCM Tools*, *Exclude Subsystems & CMD*, *None*), with interactive **Add / Replace / Delete #n** controls to save, update, and manage custom user filter configurations in `localStorage`.

---

## 2. Superficial Root Cause & Diagnostics

| Item # | Defect Symptom | Technical Root Cause |
| :--- | :--- | :--- |
| **1** | Title shows `V6.1.0` across Show-* tools | `LcmToolCatalog.psm1` (and other Show-* HTML generators) hardcode static version strings in HTML templates. In addition, the universal stylesheet (`lcm-dashboard-theme.css`) is dynamically read and inlined via `Get-Content` on every launch rather than utilizing a static, compiled `StandardTableDisplay.css` with modular cascaded stylesheets (`LCMToolCatalog.css`). |
| **2** | Static `HaSSD06` Metric Card | `card-hassd06` in `LcmToolCatalog.psm1` is hardcoded to `<div class="metric-label">HaSSD06 Subsystem</div>` and `filterBySubsystem('HaSSD06')`. |
| **3** | Unconditional Parameter Modal | `runToolSmart(idx)` in `lcm-tool-explorer.js` unconditionally calls `openRunDialog(idx)` instead of inspecting `tool.Parameters` for mandatory parameters without defaults. |
| **4** | Consoles Stay Open for `May Exit` | `noExit: activeRunningTool.NoExit !== false` in `lcm-tool-explorer.js` evaluates to true when `NoExit` is undefined/null; `openToolHelp` hardcodes `noExit: true`. |
| **5** | Help Fails on `.lnk` & Console Terminal | `openToolHelp` previously attempted dynamic command construction or .lnk parsing. Script path must be resolved statically from `tool.RelativePath` in LCM data, piped to a temporary text file, and launched in `notepad.exe`. |
| **6** | Missing Refresh Button | `btn-refresh` was removed during previous cleanups. Standard Display requires an explicit `[🔄 Refresh Data & View]` button alongside the F5 keyboard listener. |
| **7** | `LCD` in Subsystem Dropdown | Legacy `.lcm/tools/internal/tool_catalog.json` and fallback seeds in `LcmToolCatalog.psm1` contain obsolete `LCD` references. |
| **8** | Broken Back Link | `LcmToolCatalog.psm1` line 267 contains `window.location.href='../scratch/SHOW_LCM.html'` which points to a non-existent path. |
| **9** | Tools Missing `-h` (Generalized) | `Advance-Governance.ps1` and several legacy tools lack standard `[Alias('h', '?')][switch]$Help` declarations and handlers required by `RULE-PS-010`. |
| **10** | BCR Parameter Descriptions & CRP-134 | `Invoke-BeyondCompareReview.ps1` lacks `HelpMessage` on parameters and `.PARAMETER` docblocks. Addressed in tandem with `CRP-134` (accepted). |
| **11** | NOT Filtering in Filters/Search | Dropdowns only match equality; `applyFilters()` in `lcm-tool-explorer.js` token parser lacks structured field negation (`!Column:Value`). |
| **12** | Missing View Presets & Management | No saved filter combinations exist; operator must repeatedly re-select multiple dropdowns to switch between LCM core and general tools. |

---

## 3. Criticality Assessment
- **Severity**: HIGH
- **Impact**: Affects daily developer operations, tool discovery, parameter execution correctness, and help documentation accessibility across the entire LCM toolchain.

---

## 4. Affected Scope
- `Workspace_Inventory/assets/StandardTableDisplay.css` (canonical static base owned by Workspace_Inventory)
- `Workspace_Inventory/assets/LCMToolCatalog.css` (modular cascade extension)
- `Workspace_Inventory/assets/lcm-tool-explorer.js` (client application controller)
- `.lcm/modules/LcmToolCatalog.psm1`
- `Workspace_AI/tools/Advance-Governance.ps1` (and all governed scripts lacking `-h`)
- `Workspace_Inventory/tools/Invoke-BeyondCompareReview.ps1`
- `.lcm/tools/internal/tool_catalog.json` & `.lcm/config/tool_catalog.json`
- `Workspace_Inventory/data/proposals/proposals.json`

---

## 5. Proposed Remediation Plan
1. **Model A: Linked Two-Tier Static CSS Owned by `Workspace_Inventory/assets/`**:
   - Establish `Workspace_Inventory/assets/StandardTableDisplay.css` as the single static canonical stylesheet for all `Show-*` Standard Displays, establishing authoritative code ownership in `Workspace_Inventory`.
   - Extract tool-specific rules into dedicated cascading stylesheets (e.g. `Workspace_Inventory/assets/LCMToolCatalog.css`).
   - Use direct `<link rel="stylesheet">` tags (Model A) in generated HTML for full browser caching and instant hot-reloading during development.
   - Standardize version display via CSS classes (`.header-version-subtitle`, `.header-version-badge`) and eliminate hardcoded version strings across all `Show-*` generators.
2. **Subsystem Metric Binding**: Update metric card 5 to reflect the actively selected subsystem (label and tool count), making card clicking a safe no-op or reset.
3. **Smart Parameter Gating**: Update `runToolSmart(idx)` to check if the tool has mandatory parameters without defaults:
   - If mandatory parameters without defaults exist -> show `openRunDialog(idx)`.
   - If all parameters have defaults or tool has no parameters -> execute immediately via `runTool(idx)`.
4. **Strict `NoExit` Evaluation**: Enforce `noExit: Boolean(tool.NoExit)` in `lcm-tool-explorer.js` so `May Exit` tools close cleanly without leaving terminal windows open.
5. **Static LCM Script Resolution & Notepad Help Viewer**:
   - Resolve target script path directly from LCM catalog metadata (`tool.RelativePath`), completely bypassing `.lnk` shortcut parsing.
   - Execute `Get-Help <target> -Detailed` or invoke `-h`, redirect output to a temporary `.txt` file in `scratch/`, and launch via `notepad.exe`.
6. **Restore Standard Refresh Button**: Add `[🔄 Refresh]` button to the toolbar calling `window.LcmTools.refreshToolCatalog()`.
7. **Clean Subsystems & Governed Repo Discovery**: Remove `LCD` from all catalog files and scripts; establish clean repository discovery from workspace directories and settings.
8. **Fix Back Button Navigation**: Replace fallback with safe browser `history.back()` or fallback to Mission Control / Top Hub (`Show-LCM.ps1` / `SHOW_LCM.html` root).
9. **Universal CLI Help Audit Across All Tools**: Audit all `.ps1` tools across governed repositories, add `[Alias('h', '?')][switch]$Help` where missing, and enforce compliance with `RULE-PS-010`.
10. **Parameter Descriptions & CRP-134 Alignment**: Add `HelpMessage` attributes and complete `.PARAMETER` docblocks for BCR and all tools; apply `CRP-134` de-parameterization to `$BeyondComparePath`.
11. **Alternative B: Structured Negative Query Syntax**: Enhance `applyFilters()` in `lcm-tool-explorer.js` to recognize `!Column:Value` and `Column:Value` tokens (e.g. `!Audience:dev`, `!Group:LCM`, `!Env:CMD`).
12. **Filter Presets Engine & User Management (Add / Replace / Delete #n)**:
   - Add a "Filter Preset" selector to the toolbar with built-in configurations (*Default*, *LCM Core*, *General Tools*, *Exclude Subsystems & CMD*, *None*).
   - Implement interactive controls:
     - **Add**: Save current active filters (search input + column dropdowns) as a new preset.
     - **Replace #n**: Update preset `#n` with current filter state.
     - **Delete #n**: Remove user-defined preset `#n`.
   - Persist user presets across sessions in browser `localStorage`.

> [!IMPORTANT]
> **Awaiting Operator Authorization**: Per `RULE-LCM-015` and `RULE-LCM-016`, this bug report is registered in the `OPEN` state. Implementation planning and code edits will commence upon receipt of an explicit `PROCEED 133` or `PROCEED ALL` command.
