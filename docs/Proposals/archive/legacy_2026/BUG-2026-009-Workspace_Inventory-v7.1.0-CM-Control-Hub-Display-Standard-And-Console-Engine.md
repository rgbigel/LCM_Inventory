---
Proposal-ID: BUG-2026-009
CR-ID: CR-2026-049
Scope: LCM_Inventory
Version: v7.1.0
Affected-Repos: [LCM_Inventory]
Status: In_Progress
Date: 2026-09-06
Author: rgbig
Target Scope: LCM_Inventory / docs / CM_CONTROL_HUB.html, tools / Show-CmControlHub.ps1, docs / Proposals / CRP-2026-019
Affected Version Range: v7.1.0
Impacted Repositories: [LCM_Inventory]
Severity: High
---

# BUG-2026-009: CM Control Hub Display Standard Non-Conformance and Missing Console Command Engine

## 1. Defect Description & Discovery Vector
During operator workflow in the Configuration Management Control Hub (`CM_CONTROL_HUB.html`), two critical defects were observed:
1. **Display Standard Non-Conformance**: The interface is locked to a dark theme without the standard Light/Dark mode toggle (☀️ / 🌙) or `lcm_theme` localStorage persistence, lacks the unified typography and layout branding of other LCM viewers (`SHOW_TOOLS.html`, `SHOW_HA_INVENTORY.html`), lacks `LcmTablePrintAtom` integration for printing and PDF generation, and violates the Display Standard rule that table heads must be frozen (i.e. excluded from scrolling).
2. **Console Command Inertia**: Typing CM commands into the bottom docked console (such as `do #77`, `review #77`, `status`) and pressing Enter or clicking "Send / Run" produces no effect. Inspection reveals that the event handler functions `submitConsoleCommand()` and `handleConsoleKey(event)` referenced by the UI elements are completely undeclared in JavaScript, throwing uncaught `ReferenceError` exceptions.

## 2. Root Cause Analysis
1. In `CM_CONTROL_HUB.html`, the HTML elements for console interaction were added without implementing their backing JavaScript functions (`submitConsoleCommand`, `handleConsoleKey`, `setConsoleCommand`, `clearConsoleStream`). No command parser or dispatch logic existed to map commands like `do #id` to proposal state transitions.
2. `CM_CONTROL_HUB.html` did not incorporate the LCM Display Standard design tokens and layout rules: light-theme CSS variables were absent, the theme toggle button was missing from the header, `LcmTablePrintAtom` was neither inlined by `Show-CmControlHub.ps1` nor initialized on the data tables, and table headers were not sticky/frozen within a scrollable container (`thead`/`th` lacked sticky positioning and `.table-container` lacked a constrained scroll height).

## 3. Remediation Strategy
1. **LCM Display Standard Integration & Rule Codification**:
   - **Codify Rule in Display Standard Specification**: Update authoritative Universal LCM Table UI/UX Standard ([`CRP-2026-019`](file:///d:/Git_Repositories/LCM_Inventory/docs/Proposals/CRP-2026-019-LCM-v2.2.2-Standardized-Interactive-Document-Table-Viewer.md), Section 2.4) to formally mandate that *the head of table displays must be frozen, i.e., excluded from scrolling*. Column headers, sort indicators, and filter controls must remain continuously pinned and visible while scrolling records.
   - Implement frozen header styling in `CM_CONTROL_HUB.html`: Apply `overflow-y: auto`, `overflow-x: auto`, and constrained `max-height` (e.g. `calc(100vh - 380px)`) to `.table-container`, and `position: sticky; top: 0; z-index: 50/51` to `thead` and `th` in both dark and light modes.
   - Add light-theme CSS variables under `:root` and `.light-theme` in `CM_CONTROL_HUB.html`.
   - Add theme switch toggle button in header with `initTheme()`, `toggleTheme()`, and `applyTheme()` bound to `localStorage['lcm_theme']`.
   - Update `Show-CmControlHub.ps1` to locate and inline `LcmTablePrintAtom` from `.lcm\assets\lcm-table-print-atom.js`.
   - Wire `id="proposalsTable"` and initialize `LcmTablePrintAtom` on proposal and document tables with dedicated Print/PDF header action.
2. **Console Engine Implementation**:
   - Implement `submitConsoleCommand()`, `handleConsoleKey()`, `setConsoleCommand()`, and `clearConsoleStream()`.
   - Implement command parser handling:
     - `do <#id|id>` / `do all`: Transitions proposal state to `in_progress` / `processed`, logs to stream, and syncs via daemon `/sync_json` or local ledger.
     - `accept <#id>` / `accept all`: Dispatches batch acceptance.
     - `review <#id>`: Dispatches Beyond Compare 5 review.
     - `defer <#id>` / `delete <#id>`: Updates proposal state.
     - `status`: Emits real-time ledger metrics.
     - `help`: Emits interactive command cheat sheet.
3. **Verification & Readiness**:
   - Validate generated HTML script block in Node.js (0 syntax errors).
   - Test console commands and theme toggle functionality.
   - Verify table scrolling behavior ensures frozen sticky headers remain visible.
   - Run `LCM_Inventory\tools\Test-LCMRuleHealth.ps1`.
