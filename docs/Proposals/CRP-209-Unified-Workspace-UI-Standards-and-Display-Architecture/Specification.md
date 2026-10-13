# CRP-209: Unified Workspace UI Standards and Display Architecture

```yaml
CRP-ID: CRP-209
Priority: 8
Scope: Workspace-wide UI Governance, Display Standards, and Cross-Repo Presentation Architecture
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - LCM_Inventory
  - LCM_AI
  - LCM_Tools
  - LCM_Supervision
  - LCM_Shared
  - HaSSD06
  - HaSSD06_Inventory
  - RollingCalendar
  - NextBootTray
  - BootEntryManager
  - BackgroundModifier
```

## Objective

Establish an authoritative, comprehensive Configuration Management proposal and foundational rule specification that unifies, codifies, and governs all User Interface (UI) and display aspects across the entire workspace (LCM core repositories, child repositories, subsystems, and unonboarded utilities).

This document consolidates all historical context, evolutionary milestones, operational logs, existing documentation, and concrete implementations spanning interactive HTML dashboards, CSS design tokens, JavaScript filtering engines, native Windows Desktop GUIs (WPF, Windows Forms, NotifyIcon System Tray), headless print/PDF generation, and interactive desktop session dispatching.

---

## 1. Lineage & Chronological Evolution: Oldest to Newest

This section traces the chronological evolution of UI paradigms, specifications, and defect remediations across the workspace from earliest prototypes to the current baseline:

```
[Phase 1: Raw Scripts & Monolithic HTML] (Pre-10.0.0)
   ├── Raw PowerShell console output & ad-hoc Write-Host color tables.
   ├── Isolated WinForms dialogs in BootEntryManager (OpenFileDialog).
   ├── Standalone NextBootTray system tray utility (WinForms NotifyIcon).
   └── Monolithic single-file HTML reports with hardcoded inline CSS styling.
          │
[Phase 2: LCM Foundation & First-Generation Dashboards] (10.0.0 - 10.0.0)
   ├── CRP-019 / CRP-025 / CRP-026: CM Control Hub & Inventory Viewer introduced.
   ├── BUG-067: Browser table Port 9876 channel compliance & REST bridge.
   ├── CRP-101 / CRP-102 / CRP-103: Universal theme engine & Standard Document Table Viewer.
   └── BUG-097 / BUG-111 / BUG-120: Tool Explorer @-prefix filtering, Mermaid folding, and print hang fixes.
          │
[Phase 3: Standard Display Design System Codification] (10.0.0 - 10.0.0)
   ├── CRP-108: Universal Table Standard Display Enhancements.
   ├── CRP-109: Mermaid Diagram standard and Markdown diagram formatting.
   ├── CRP-110: Universal Multi-Channel Progress Indicator Engine (LcmProgressAtom).
   ├── CRP-115 / BUG-126 / BUG-127: Universal F5 keyboard refresh, PS 5.1 serialization hang fixes, tool version sync.
   ├── CRP-128 / CRP-129 / CRP-130: Universal Multi-Page Table Print Engine & Desktop Editor Dispatch.
   ├── CRP-142: Codification of DisplayStandardsPolicy.md (RULE-DSP-001 through 008).
   ├── CRP-143 - CRP-150: HaSSD06 Subsystem UI suite (Live entities, Devices explorer, Automations/Scripts actions).
   ├── CRP-151: Standard Display Universal Action Logging Engine.
   └── CRP-156: Separation of presentation artifacts (.html) into data artifacts (.json).
          │
[Phase 4: Ergonomics, Daemon Dispatch & Slicing] (10.0.0 - 10.0.0)
   ├── CRP-158 / CRP-160: Control Hub NOT negation syntax, open filters, minimal stream & notepad output.
   ├── CRP-164: Document Viewer layout optimization and sticky header tuning.
   ├── CRP-171 / CRP-176: ShowTools default view, execution metrics, and SuperController trampoline.
   ├── CRP-177 / CRP-180 / CRP-182: Tool Explorer log truncation, column realignment, bulk taxonomy, and App grouping.
   ├── CRP-184: Runtime dropdown column widening for high-DPI displays.
   ├── CRP-187 / CRP-188: Decoupling, Element Telemetry Logging, and dynamic HTML-JSON runtime contract.
   └── CRP-196: Control Hub Lifecycle & Action Model redesign (multi-action buttons, real-time status reflection).
          │
[Phase 5: Print Engines, Subsystem WPF & Multi-Repo Alignment] (10.0.0 - Current)
   ├── CRP-198: RollingCalendar automated print-ready HTML grid matrix & headless Edge PDF generation.
   ├── HaSSD06 Show-HaAuthDialog: Modern WPF modal authentication dialog with password peek and mutation preview.
   ├── BUG-205: Control Hub numeric priority filter crash remediation.
   └── CRP-208: Repository naming migration cutover across all UI asset paths and trampolines.
```

### Detailed Chronological Milestone Table

| Timeline / Proposal | Category | Primary Repos | UI Aspects Introduced & Codified |
|:---|:---|:---|:---|
| **Pre-10.0.0** | Desktop GUI | `BootEntryManager`, `NextBootTray` | WinForms `OpenFileDialog` integration; WinForms `NotifyIcon` system tray app with dynamic context menus for EFI boot entries. |
| **CRP-019 / CRP-025** | HTML Dashboard | `LCM_Inventory` | CM Control Hub foundation; single-instance dashboard coordination and tab lifecycle management. |
| **CRP-026** | HTML Dashboard | `LCM_Inventory` | Inventory Viewer interactive action buttons, inspect drawer, and mechanical data versioning exemption. |
| **BUG-067** | IPC / Web | `LCM_Inventory` | Port 9876 REST communication channel compliance for browser-to-desktop command execution. |
| **CRP-101 / CRP-102** | CSS / Layout | `LCM_Inventory`, `LCM_Tools` | Universal Dark/Light theme persistence via `localStorage.getItem('lcm_theme')`; top navigation breadcrumbs; high-contrast tokens. |
| **CRP-103 / CRP-108** | Table Engine | Workspace-wide | `StandardTableDisplay.css`; double-row sticky header layout (`<th>` sort row, `.col-filter-row` input/select row); column negation filtering. |
| **CRP-109** | Markdown UI | Workspace-wide | Mermaid flowchart diagram standards and `Format-LcmMarkdownDiagrams.ps1` AST folding engine. |
| **CRP-110** | Terminal UI | `LCM_Shared` | `LcmProgressAtom.psm1` multi-channel terminal progress indicators, spinner glyphs, and percentage meters. |
| **CRP-115 / BUG-126** | UX Interaction | `LCM_Inventory` | Universal F5 keyboard refresh binding; eliminated redundant "Refresh" buttons; fixed PS 5.1 JSON serialization hang. |
| **CRP-128 / CRP-129** | Print & OS Dispatch | Workspace-wide | `lcm-table-print-atom.js` multi-page table print & PDF export; desktop editor dispatch (`Invoke-InteractiveDesktop.ps1`). |
| **CRP-142** | Governance Rule | `LCM_AI` | Formal codification of [`DisplayStandardsPolicy.md`](file:///d:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md) (`RULE-DSP-001` through `008`). |
| **CRP-143 - CRP-150** | Subsystem UI | `HaSSD06_Inventory` | Dedicated Devices Explorer, Live Entities status tables with color-coded toggle chips, automations/scripts execution suite. |
| **CRP-151** | Telemetry UI | Workspace-wide | Standard Display Universal Action Logging Engine; action feedback banners and execution telemetry drawers. |
| **CRP-156** | Architecture | Workspace-wide | Separation of presentation artifacts: static HTML viewer templates separated from dynamic JSON data payloads. |
| **CRP-158 / CRP-160** | Table Filtering | `LCM_Inventory` | Control Hub `!Column:value` negation token parser; minimal stream output and Notepad review integration. |
| **CRP-171 / CRP-176** | Hub Ergonomics | `LCM_Tools` | `ShowTools` default view, execution metrics cards, and canonical `SuperController.cmd` launch trampoline. |
| **CRP-177 - CRP-184** | Table Ergonomics | `LCM_Tools` | Log truncation, column realignment, bulk taxonomy assignment modal, and dropdown column widening. |
| **CRP-188** | Telemetry Contract | `LCM_Inventory` | Element Telemetry Logging (`element_id`, click tracking) and dynamic HTML-JSON runtime contract. |
| **CRP-196** | Hub Redesign | `LCM_Inventory` | CM Control Hub Action Model redesign: multi-action lifecycle buttons (`Proceed`, `Do`, `BCR`, `Complete`), real-time status reflection. |
| **CRP-198** | Print Matrix | `RollingCalendar` | Print-ready CSS calendar grid matrix; headless Edge PDF rendering (`--headless --print-to-pdf`); clean page breaks. |
| **HaSSD06 Dialog** | Desktop GUI | `HaSSD06` | Modern WPF modal dialog (`Show-HaAuthDialog.ps1`) for JIT ephemeral credentials with password peek and mutation preview. |
| **BUG-205** | UI Bugfix | `LCM_Inventory` | Control Hub numeric priority filter crash remediation when parsing empty/null priority attributes. |
| **CRP-208** | Naming Migration | Workspace-wide | Repository identity cutover (`Workspace_*` $\rightarrow$ `LCM_*`) across all HTML headers, asset scripts, and API routes. |

---

## 2. Affected Areas of Each UI Specification by Repository

This section catalogs every UI surface, asset, and presentation mechanism across the workspace, organized by repository:

### 2.1. LCM Core Repositories (`LCM_*`)

#### `LCM_Inventory` (Configuration Management & Hubs)
* **`CM_CONTROL_HUB.html` (`Show-LcmControl.ps1`, `control-hub.html`)**:
  - The flagship CM operational cockpit.
  - Multi-action lifecycle buttons per proposal: `Proceed`, `Do`, `BCR`, `Complete`, `Delete`, `Defer`.
  - Filter bar: Text query, status pills (`All`, `Open`, `Blocked`, `Suggested`, `In Progress`, `Review`, `Completed`), and numeric priority slider.
  - Detail drawer: Slide-out panel rendering `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
  - Real-time execution log drawer capturing PowerShell runner telemetry.
* **`WORKSPACE_INVENTORY_VIEWER.html` (`Show-WorkspaceInventoryApp.ps1`)**:
  - Full inventory table across all 29+ repositories.
  - Classification filters (`lcm-governed`, `subsystem`, `standard-git`, `unonboarded-candidate`).
  - Action buttons: Open in Explorer, launch BCR, run readiness tests, inspect config.
* **`WORKSPACE_READINESS.html` (`Show-WorkspaceReadiness.ps1`)**:
  - Visual readiness dashboard reporting tiered quality gate pass/fail status per repository.
  - Visual diagnostic badges for AST, Pester, Line Endings, and Elevation consistency.
* **`LCM_SIDECAR.html` (`Show-LcmSidecar.ps1`)**:
  - Persistent lightweight floating sidecar viewer providing rapid status snapshots and one-click actions.
* **`CM_CRP_DATES_READONLY.html`**:
  - Read-only timeline table showing proposal creation, suggestion, progress, and push timestamps.
* **Desktop Launcher (`Show-LcmActiveLauncher.ps1`)**:
  - WPF desktop utility providing 1-click execution cards for primary tools.
* **Assets Engine (`assets/`)**:
  - `StandardTableDisplay.css`, `LCMToolCatalog.css`, `lcm-table-engine.js`, `lcm-table-print-atom.js`, `lcm-tool-explorer.js`.

#### `LCM_Tools` & `.lcm` (Platform Tooling Hub)
* **`Show-ToolsExplorer.ps1` (`ToolExplorer.cmd`, `ToolsExplorer.cmd`)**:
  - The authoritative workspace tool directory viewer.
  - Filterable by Audience (`User` vs `Dev`), Subsystem (`HaSSD06`, `LCM`, `SystemConfiguration`), Environment (`PS1`, `CMD`, `PY`), and Role.
  - Dynamic interactive modals for tool taxonomy editing and short-name alias management.
  - Action buttons: Run (`▶️`), Inspect Source (`🔍`), Help (`❓`), Copy Command (`📋`).
* **`Show-Rules.ps1` (`Show-LCMRules.ps1`)**:
  - Authoritative rule visualizer rendering all 17 canonical LCM governance rules with search and rule code badges.
* **`Show-Subsystems.ps1`**:
  - Subsystem status visualizer summarizing disjunct operational domains (`HaSSD06`, `LCM_Supervision`).
* **`Show-CmdFolderAnalysis.ps1`**:
  - Visual audit tool displaying trampoline health, orphan batch files, and target script alignment.
* **`LcmDesktopDaemon.ps1` (`Show-LcmDaemon.ps1`)**:
  - Background HTTP REST daemon on port 9876 handling browser UI action execution requests (`POST /execute`).
* **`Invoke-InteractiveDesktop.ps1`**:
  - Session 0 $\rightarrow$ Session 1 process dispatcher ensuring browser dashboards, File Explorer, and Notepad windows launch visibly on the user's interactive desktop.

#### `LCM_Supervision` (Telemetry & Status Observation)
* **`SUPERVISION_HUB.html` (`Show-Supervision.ps1`)**:
  - Real-time task telemetry, background runner status, and health observation dashboard.
  - Live pulse indicators for active background daemons.

#### `LCM_Shared` (Reusable Functional Library)
* **`LcmProgressAtom.psm1`**:
  - Terminal-based UI atom providing ANSI percentage bars, multi-channel progress reporting, and step indicators.
* **`Logging.psm1`**:
  - Standardized console output formatting: `[INFO]`, `[WARN]`, `[ERROR]`, `[ACTION]`, and `[SUMMARY]` blocks.

---

### 2.2. Subsystems (`HaSSD06*`)

#### `HaSSD06_Inventory`
* **`SHOW_HA_INVENTORY.html` (`Show-HaInventoryApp.ps1`, `Build-HaInventoryViewer.ps1`)**:
  - Domain-specific dashboard for Home Assistant OS components.
  - Dedicated tabs: Integrations, Add-ons, HACS custom repositories, Automations, Scripts, and Devices.
* **`Entities_Inventory_HaSSD06.html`**:
  - High-density table listing hundreds of Home Assistant entities, states, friendly names, and device links.
  - Quick action subpanels for entity and device renaming.

#### `HaSSD06` (Home Assistant OS Subsystem)
* **`Show-HaAuthDialog.ps1`**:
  - Interactive WPF desktop modal dialog prompting for JIT ephemeral operator credentials.
  - Features: Password masking toggle (`👁️ Show/Hide`), planned mutation payload preview, timeout counter, and secure volatile memory storage.

---

### 2.3. Desktop Utilities & Candidate Repositories

#### `NextBootTray`
* **`NextBootTray.ps1`**:
  - Native Windows desktop System Tray (`NotifyIcon`) application built using `System.Windows.Forms`.
  - Left-Click Context Menu: Live enumeration of active BCD boot entries, radio-style checked state for default entry, one-click "Boot Now" direct reboot action.
  - Right-Click Context Menu: Tool links, documentation viewer, and graceful process exit.
  - Background loop with low memory footprint and zero CPU polling overhead.

#### `BootEntryManager`
* **`BootEntryManager.ps1`**:
  - Hybrid CLI / GUI tool.
  - Uses `System.Windows.Forms.OpenFileDialog` for interactive BCD backup and EFI payload selection when run interactively.

#### `RollingCalendar`
* **`Invoke-RollingCalendar.ps1`**:
  - Dynamic HTML Calendar Print Matrix generator.
  - Builds a strict CSS grid calendar layout (`display: grid`, 7 columns, fixed-height rows, uppercase day headers, multi-day span bars).
  - Headless browser print execution: Invokes `msedge.exe --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf` to emit high-resolution printable PDF documents.
  - Dedicated print stylesheet rules: `@page { size: landscape; margin: 5mm; }`, `@media print`.

#### `BackgroundModifier` & `PowerBGInfo`
* **Desktop Wallpaper Canvas UI**:
  - Generates and composites dynamic desktop background images (wallpaper overlay UI).
  - Renders system identity telemetry, host specs, IP addresses, and build numbers directly onto the desktop wallpaper bitmap using .NET `System.Drawing.Graphics`.

#### Sibling Scripting Repositories (`VolumeInventory`, `AuthorizeMasterUser`, `BGMSAMVInv`, etc.)
* **Console Table UI**:
  - Structured console tabular rendering (`Format-Table`, ANSI colored status tags, standardized summary footers).

---

## 3. Conflicting, Inconsistent, and Undocumented UI Aspects

A thorough audit of the existing codebase reveals significant discrepancies between actual UI implementations and the existing governance policy ([`DisplayStandardsPolicy.md`](file:///d:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md)):

### 3.1. Framework Scope Gap: HTML Exclusivity vs. Multi-Framework Reality
* **Current Policy Limitation**: `DisplayStandardsPolicy.md` is titled and scoped purely around HTML table viewers (`StandardTableDisplay.css`, double-row sticky headers, web tables).
* **Undocumented Reality**: The workspace actively utilizes multiple distinct UI frameworks:
  1. **WPF (.NET XAML / PresentationFramework)**: `HaSSD06/Show-HaAuthDialog.ps1` and `LCM_Inventory/Show-LcmActiveLauncher.ps1`.
  2. **Windows Forms (.NET System.Windows.Forms)**: `NextBootTray/NextBootTray.ps1` (NotifyIcon tray app) and `BootEntryManager.ps1` (`OpenFileDialog`).
  3. **Print-to-PDF / Headless Rendering**: `RollingCalendar/Invoke-RollingCalendar.ps1` (CSS Print Paged Media + Headless Chromium).
  4. **Wallpaper Canvas Graphics**: `BackgroundModifier` and `PowerBGInfo` (`System.Drawing`).
  5. **Terminal / Console UI**: `LcmProgressAtom.psm1` (ANSI escape sequences, terminal progress meters).
* **Conflict**: There are currently zero governance rules defining visual styling, color tokens, font hierarchies, error handling, or lifecycle behavior for WPF, WinForms, Print media, or Console UI atoms.

### 3.2. Styling & Design Token Inconsistencies
* **Hardcoded Styling Violations**: While `RULE-DSP-001` mandates CSS variables from `StandardTableDisplay.css`, several legacy and subsystem viewers contain hardcoded hex colors (e.g. `color: #333`, `background: #f8f9fa`, `#1e293b`) and ad-hoc inline styles.
* **Theme Variable Fragmentation**:
  - Some viewers reference `--bg-primary`, `--bg-secondary`, `--accent`.
  - Other tools reference `--theme-bg`, `--card-bg`, or custom dark mode selectors (`body.dark-mode` vs `body[data-theme="dark"]`).
  - `RollingCalendar` defines an entirely distinct embedded CSS palette (`#003366`, `#e6f0fa`, `#2d3748`) without referencing the workspace design tokens or theme toggles.

### 3.3. Table Engine Divergence & Search Matching
* **Static vs. Dynamic Binding**:
  - `Show-ToolsExplorer.ps1` uses `lcm-tool-explorer.js` with tight column-specific dropdowns and action modals.
  - `CM_CONTROL_HUB.html` uses an independent internal state machine for proposal status pills and numeric priority filtering.
  - `SHOW_HA_INVENTORY.html` uses custom entity-matching logic.
* **Negation Syntax Parity**:
  - `RULE-DSP-006` requires support for `!exclude` and `Column:!value` negation syntax via `LcmTableEngine.filterTable()`.
  - However, several simpler table views only implement basic string `.indexOf()` filtering, failing on negation tokens.

### 3.4. Session 0 vs. Session 1 Desktop Execution Traps
* **Inconsistent Dispatch**: While `RULE-PS-011` and `RULE-DSP-008` mandate routing GUI launches through `Invoke-InteractiveDesktop.ps1`, some scripts still contain bare `Start-Process $htmlPath` fallbacks that silently fail or become invisible when invoked from non-interactive background agent workers.
* **Daemon Port 9876 Hardcoding**: Multiple web dashboards assume `http://127.0.0.1:9876` is always available for action execution, without a standardized in-browser visual fallback banner when the background daemon is not running.

### 3.5. Keyboard Navigation & Accessibility Gaps
* **Undocumented Shortcuts**: While `CRP-115` established the universal `F5` refresh binding, other standard desktop expectations (`Escape` to close drawers/modals, `Ctrl+F` focus search input, arrow key table row navigation) are implemented haphazardly or entirely missing.

---

## 4. Recommended Areas Where Existing Specifications Do Not Cover UI Needs

To elevate workspace UI to a cohesive, professional, and robust standard, the following critical domains must be governed by an expanded or unified UI rule:

### 4.1. Universal Desktop GUI Standard (WPF & WinForms Invariants)
* **Visual Parity with Web Tokens**: Desktop dialogs (WPF and WinForms) must mirror the typography (`Inter` / `Segoe UI Variable`), dark/light color palette, and border radius of `StandardTableDisplay.css`.
* **DPI & Multi-Monitor Resilience**: All WinForms and WPF applications must explicitly declare Per-Monitor DPI V2 awareness (`<dpiAware>true/pm</dpiAware>`) to prevent blurry text on 4K/high-DPI scaling.
* **Window Lifecycle & Session 1 Invariant**: Desktop windows must center on the active cursor's monitor, never spawn off-screen, and support `Escape` key dismissal for modal dialogs.

### 4.2. System Tray & Background Utility Standard
* **Lifecycle Governance**: Background tray utilities (`NextBootTray`) must implement:
  - Single-instance mutex enforcement to prevent duplicate tray icons on repeated script executions.
  - Clean exit hooks removing the icon from the Windows Shell Notification Area upon process termination.
  - Non-blocking asynchronous UI loops (`Application.Run()` on dedicated STA threads).

### 4.3. Print-to-PDF & Paged Media Standard
* **Print Layout Specification**: Tools emitting printable HTML reports or calendars (`RollingCalendar`, table export) must adhere to a standardized Paged Media specification:
  - Strict `@page` rule declarations with explicit margins (`margin: 5mm` or `10mm`).
  - Table header repetition (`thead { display: table-header-group; }`) across multi-page PDF splits.
  - Prohibition of orphaned row breaks (`tr { break-inside: avoid; }`).
  - Headless browser print orchestration wrapper standard (`Export-HtmlToPdf.ps1`).

### 4.4. Real-Time Telemetry & Action Execution Feedback
* **Unified Action State Machine**: When an action button (e.g. `Proceed`, `Run`, `Inspect`) is clicked in any HTML dashboard:
  - Immediate visual state transition: Button transitions to disabled with an animated spinner (`⏳ Running...`).
  - Real-time feedback banner: Standard toast notification displaying tool name, target, and elapsed time.
  - Result disposition: Clean success (`✅ Completed`) or failure (`❌ Failed`) chip with one-click link to the execution log on disk.
  - Daemon offline fallback: If Port 9876 is unreachable, copy the CLI command to clipboard and prompt the user with clear instructions.

### 4.5. Terminal & Console UI Presentation Standard
* **Console Ergonomics**: Standardize CLI output across all PowerShell tools:
  - ANSI 24-bit TrueColor / 16-color graceful degradation.
  - Standardized column-aligned console summary boxes.
  - Unified progress bars using `LcmProgressAtom.psm1`.

---

## 5. Authoritative Reference UI Design Pattern: `CM_CONTROL_HUB_IMPLEMENTATION_0.html`

The prototype agreed upon in [`LCM_Inventory/assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html`](file:///d:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html) establishes the authoritative, production-grade UI design pattern for all future LCM dashboards and interactive viewers.

### 5.1. Reference Design Tokens & Typography
* **Typography**:
  - Code, IDs, and Metrics: `IBM Plex Mono` (weights 400, 500, 600), Consolas, monospace.
  - UI Labels, Headers, and Prose: `IBM Plex Sans` (weights 400, 500, 600, 700), "Segoe UI", sans-serif.
* **Curated Antigravity-IDE-like Light Mode Design System Palette (Authoritative Default)**:
  - Surfaces: Canvas (`--canvas: #edf1ef`), Surface (`--surface: #ffffff`), Soft Surface (`--surface-soft: #f6f8f7`), Topbar Dark Slate (`#132b33`), Gold Accent Line (`#d8a840`).
  - Ink & Lines: Primary Text (`--ink: #172127`), Muted Secondary (`--muted: #5d6b72`), Subtle Line (`--line: #ccd5d1`), Strong Border (`--line-strong: #aab8b2`).
  - Semantic Status Colors:
    - Active / Progress: `--blue: #176b87`, Soft: `--blue-soft: #e0f0f4`.
    - Complete / Healthy: `--green: #2d764d`, Soft: `--green-soft: #e4f2e8`.
    - Review / Attention: `--amber: #9a6510`, Soft: `--amber-soft: #fff2d7`.
    - Blocked / Error: `--red: #a53d36`, Soft: `--red-soft: #fce8e5`.
    - Held / Specialized: `--violet: #6b4c8d`, Soft: `--violet-soft: #eee8f5`.
* **Iconography**:
  - Replaces legacy emoji glyphs with crisp, modern SVG vector icons via **Lucide** (`data-lucide="..."`).

### 5.2. Core Layout & Component Innovations
1. **Application Topbar (`.topbar`)**:
   - Deep slate container (`#132b33`) with gold indicator bottom border (`3px solid #d8a840`).
   - Integrated context selector / app switcher (`Foundation`).
   - Centered global search bar with embedded magnifying glass icon.
   - Live synchronization indicator (`.sync-dot` pulsing green).
   - Top action cluster: Theme toggle, Refresh, Help, and Back navigation.
2. **Compact Filter & Mode Toolbar (`.control-row`)**:
   - Replaces cumbersome table-header input rows with a single, elegant horizontal toolbar.
   - Segmented `.control-group` dividers for Preset, Mode (`Work queue`), Intern filter check, Status dropdown, Scope dropdown, and Sort order.
   - Right-aligned Reset button with distinctive red accent.
3. **Status Rail Pipeline Bar (`.status-rail`)**:
   - 7-stage horizontal pipeline visualization showing live proposal counts across states:
     `Open` (recorded) $\rightarrow$ `Active` (in progress) $\rightarrow$ `Review` (BCR disposition) $\rightarrow$ `Complete` (commit ready) $\rightarrow$ `Published` (remote baseline) $\rightarrow$ `Held` (reason required) $\rightarrow$ `Cancelled` (superseded).
   - Dynamic active underline and soft accent fill indicating current cohort filter.
4. **Interactive Work Queue Table (`.proposal-table`)**:
   - Row selection checkboxes with highlighted row background and 3px blue active left border.
   - Clean, mono-spaced proposal IDs (`CRP-###`, `BUG-###`), title, and origin repository badge.
   - Two-tone semantic state pills (`.state-badge`).
   - Mini ellipsis action trigger (`.mini-action`).
5. **Horizontal Execution Ledger Timeline (`.timeline` / `.step`)**:
   - Clear visual 8-stage stepper tracking a proposal's exact lifecycle progression:
     `Scope` (recorded) $\rightarrow$ `Checkpoint` (SHA saved) $\rightarrow$ `Apply` (docs) $\rightarrow$ `Design` (contracts) $\rightarrow$ `Verify` (later) $\rightarrow$ `BCR` (review) $\rightarrow$ `Commit` (local) $\rightarrow$ `Publish` (remote).
   - Circular step indicators with status styling (`.done` filled green, `.current` blue halo).
6. **Selection and Bulk Work Cohort Panel (`.selection-panel`)**:
   - Split layout: Left pane displays checked cohort items; Right pane offers cohort-validated bulk actions (`Start or resume`, `Hold with reason`, `Open review`, `Cancel`).
   - Execution parameter toggles (`Testing`, `Trace`, `Focused`, `Tight review`).

---

## 6. Draft Rule Architecture: Proposed `RULE-UI` Policy Suite

We propose consolidating and expanding `DisplayStandardsPolicy.md` into the comprehensive **Workspace UI & Display Governance Policy** (`RULE-UI-001` through `RULE-UI-015`), natively incorporating the `CM_CONTROL_HUB_IMPLEMENTATION_0.html` architecture:

```
RULE-UI-001: Canonical Design System Tokens & Typography (IBM Plex Mono/Sans + Antigravity-IDE-like Light Mode Default Palette)
RULE-UI-002: Universal Light (Default) / Dark Theme Persistence (localStorage + WPF/WinForms parity)
RULE-UI-003: Application Topbar, Control Row Toolbar & Status Rail Pipeline Architecture
RULE-UI-004: Tokenized Search Engine & Column Negation Matching (LcmTableEngine)
RULE-UI-005: Vector Iconography Standard (Lucide SVG Integration with Local Vendor Fallback)
RULE-UI-006: Interactive Desktop Dispatch Invariant (Session 1 Routing via Invoke-InteractiveDesktop)
RULE-UI-007: Standard Desktop Dialog Specification (WPF & Modal UX Parity)
RULE-UI-008: System Tray Application Lifecycle & Single-Instance Mutex
RULE-UI-009: Headless Print-to-PDF & CSS Paged Media Standard
RULE-UI-010: Execution Ledger Horizontal Timeline & Bulk Cohort Action Panel
RULE-UI-011: Terminal Console Formatting, ANSI Palette & Progress Atoms
RULE-UI-012: Universal Keyboard Shortcuts (F5 Refresh, ESC Dismiss, / Search Focus)
RULE-UI-013: High-DPI Scaling & Per-Monitor V2 Resilience
RULE-UI-014: Zero-Hardcoded Styling Invariant & AST UI Verification
RULE-UI-015: Static Presentation Template vs. Dynamic Data Payload Separation
RULE-UI-016: Dynamic Tool Version & Runtime Provenance Display Invariant
```

---

## Non-Goals

* Rewriting existing working WinForms or WPF applications from scratch.
* Forcing web technologies (e.g. Electron / WebView2) into lightweight, specialized desktop tools where native WinForms/WPF is already efficient.
* Imposing heavy external JavaScript frameworks (React, Angular, Vue); vanilla HTML/CSS/JS remains the authoritative standard for maximum performance and zero dependency overhead.
