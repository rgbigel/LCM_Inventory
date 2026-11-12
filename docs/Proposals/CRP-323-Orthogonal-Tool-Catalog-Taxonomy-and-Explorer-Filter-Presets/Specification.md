# Specification: CRP-323

## Document Information
- **Proposal ID**: `CRP-323`
- **Title**: Orthogonal Tool Taxonomy: SubSystem Unification, Role Absorption into Category, and Explorer Filter Presets
- **Author**: Rolf & Antigravity (LCM Governance)
- **Status**: Draft (Awaiting Gate 1 Operator Review)
- **Date**: 2026-11-12
- **Target Repository**: `LCM_Inventory`
- **Impacted Subsystems**: `LCM_Inventory`, `LCM_Tools`, `SystemConfiguration`, `HaSSD06`, `ShowTools` (`ToolExplorer`), `ShowCM` (`CM_CONTROL_HUB`), SQLite Ledger (`proposals.db`)

---

## 1. Executive Summary & Problem Statement

The LCM Tool Catalog (`tool_catalog.json`), Tool Explorer (`ShowTools` / `ToolExplorer.html` / `Show-ToolIntents.ps1`), and Control Hub (`ShowCM` / `CM_CONTROL_HUB.html`) suffer from dimensional entanglement and semantic inflation:
1. **Entangled Subsystem Boundaries**: The host PC (`SystemConfiguration`), external subsystems (`HaSSD06`), core infrastructure (`LCM`), and upcoming `Sandboxes` are fundamentally all **Subsystems** in architecture and documentation. Previously, some were placed in `Category` (e.g. `Subsystem - Home Assistant`, `System & Hardware`) while others were in `Group`. Groups are no longer needed; all targets belong in a single unified **`SubSystem`** dimension.
2. **Superfluous `Role` Column**: The `Role` column (with values like `Diagnostics`, `QualityGate`, `Elevation`, `Recovery`, `Repair`, `Gateway`, `Utility`) is redundant with a well-modeled `Category`. By absorbing these functional actions directly into `Category`, the `Role` column becomes completely superfluous and is eliminated.
3. **Misassigned Audiences vs. Presets**:
   - `Developer` is currently misclassified as an `Audience`. In practice, "Developer" is a composite filter preset that combines `User`, `Maintenance`, `Internal`, and subsystem manipulation tools.
   - `Internal` is strictly an **`Audience`** (tools invoked by the runtime, daemons, or background automation), not a filter preset.
   - `User` is the primary daily operator audience and must serve as the clean default view.
4. **Tool Catalog SQLite Migration (`ShowTools` Backing Store)**:
   - Just as `CRP-322` converted the proposals ledger (`proposals.json`) to SQLite, `tool_catalog.json` must be migrated to a dedicated SQLite engine (`tools.db` with table `tools`).
   - The flat JSON file (~6000 lines) causes parsing overhead and memory churn in PowerShell. Backing `ShowTools` with SQLite enables sub-millisecond parameterized lookups, indexed preset filtering, and provides an immediate foundation for a high-performance Go CLI implementation.
   - Operates under the Dual-State Projection Architecture: binary `tools.db` (git-ignored for zero repo bloat) paired with tracked `tools.sql` text export.

---

## 2. Core Architectural Invariants

### Invariant 1: Three Strictly Orthogonal Dimensions
Every tool in `tool_catalog.json` must be classified across exactly three independent, mutually orthogonal axes:

1. **`Audience`** (*Who is intended to invoke this tool?*):
   - **`User`** (Daily human operator workflows and direct commands; the default view).
   - **`Maintenance`** (Tools managing, auditing, or repairing system/subsystem parameters, invariants, hardware suppression, or LCM infrastructure).
   - **`Internal`** (System-internal tools, daemon endpoints, automation handlers, AST validators, and progress atoms).

2. **`SubSystem`** (*Which subsystem is targeted / where does the tool reside?* — Replaces the obsolete `Group` column):
   - **`PC` / `SystemConfiguration`** (Host Windows PC, hardware interlocks, system settings, desktop customization).
   - **`LCM`** (Core LCM architecture, cross-repository governance).
   - **`LCM_Inventory`** (Inventory catalogs, proposals ledger, tool trampolines).
   - **`LCM_AI`** (Governance rules hub, decision cascade, Gemini / Copilot integration).
   - **`LCM_Tools`** (Diagnostic, reasoning, and operator support tools).
   - **`HaSSD06`** (Home Assistant OS subsystem).
   - **`Sandboxes`** (Isolated development and testing worktrees).

3. **`Category`** (*What functional domain and resource is operated upon?* — Absorbs legacy `Role`):
   - **`File System & Search`** (File search, directory navigation, Explorer integration, integrity verification).
   - **`Backup & Recovery`** (Macrium baselines, restore points, disaster recovery snapshots).
   - **`Governance & Proposals`** (CRPs, specifications, rules, review cohorts, Strategies / RFCs, proposals ledger).
   - **`Review & Quality Gates`** (Beyond Compare visual diffs, BCR, drift inspection, AST/BOM readiness gates).
   - **`Elevation & Access`** (UAC privilege elevation, `do`, execution gateway, JIT credentials, ACL audits).
   - **`Diagnostics & Telemetry`** (Audit logs, performance metrics, health checks, AI reasoning traces, failure analysis).
   - **`Configuration & Customization`** (System tweaks, fonts, shortcuts, settings, desktop setup).
   - **`Environment & Runtimes`** (Python/PowerShell environments, PATH management, module linkers).
   - **`Execution Gateway`** (Universal command gateway `run`, trampolines, CLI shims, daemon bridges).

### Invariant 2: Elimination of the `Role` Column
The `Role` column is formally removed from `tool_catalog.json`, `tool_explorer_options.json`, and the Tool Explorer UI. Its useful verbs and functional distinctions are absorbed into the enriched `Category` dimension.

### Invariant 3: Default "Operator / User" View
When Tool Explorer opens, it defaults to:
- `Audience = User`
- Clean, focused view of actionable daily operational commands (`run`, `bcr`, `ToolExplorer`, `ShowRules`, `MountMacriumBaseline`, `RenameProposal`).

### Invariant 4: Filter Presets & "NoInternals" Developer Filtering
`Developer` is eliminated as a raw `Audience` property, and `Internal` is strictly an **`Audience`** (never a preset, removing duplication). Tool Explorer introduces clean single-click **Filter Presets**:
- **Preset `User` (Default)**: `Audience in ['User']` (Daily operational commands).
- **Preset `Developer`**: Unlocks subsystem tools and manipulation scripts across `User` and `Maintenance`, defaulting to **`NoInternals`** (`Audience in ['User', 'Maintenance']`). The orthogonal `Audience` column filter permits opting into `Internal` tools on demand.
- **Preset `Maintenance`**: `Audience in ['Maintenance']` (System & subsystem parameters, invariant enforcers).
- **Preset `All`**: Unfiltered catalog (`Audience in ['User', 'Maintenance', 'Internal']`).

### Invariant 5: Strategy Orientation & Forward-Compatibility Demarcation
While the formal Strategy relational mapping engine, consistency validator, and `ShowStrategies` dashboard are being introduced in **CRP-324**, CRP-323 serves as the foundational delivery slice of the upcoming strategic orientation:
- **Strategic Direction**: *Tool Taxonomy, Fast Discovery & High-Performance Execution* (spanning CRP-323, CRP-204, CRP-213, and CRP-254).
- **Forward-Compatibility Invariant**: CRP-323's category architecture (`Governance & Proposals`), options schema, and UI layouts MUST be forward-compatible with Strategy artifacts and navigation.
- **Explicit Non-Goal**: Implementing the `strategies` database schema, referential integrity triggers, or `ShowStrategies` view is strictly out-of-scope for CRP-323 and is owned exclusively by **CRP-324** per `RULE-LCM-027`.

---

## 3. Migration Plan & Impact Analysis

1. **Schema & Options**:
   - Update `tool_explorer_options.json`:
     - Rename `Subsystems` to `SubSystems`: `["PC", "LCM", "LCM_Inventory", "LCM_AI", "LCM_Tools", "HaSSD06", "Sandboxes"]`.
     - Delete the `Roles` array.
     - Replace `Categories` with the 9 enriched functional categories.
     - Set `Audiences` to `["User", "Maintenance", "Internal"]`.
2. **Catalog Generator (`Update-ToolCatalog.ps1`)**:
   - Drop generation of `"Role"` property in tool objects.
   - Rename `"Group"` to `"SubSystem"`.
   - Update classification rules to map tools into the new 9 categories and 3 audiences.
3. **Tool Explorer UI (`ToolExplorer.html` / `Show-ToolIntents.ps1`)**:
   - Remove `Role` table column and dropdown filter.
   - Rename `Group` dropdown filter to `SubSystem`.
   - Add Preset toolbar buttons (`User (Default)`, `Developer`, `Maintenance`, `Internal`, `All`).
4. **Readiness & Parity**:
   - Ensure 6/6 General Readiness gates pass across all governed repositories.

---

## 4. Acceptance Criteria (Gate 1 Gatepost)
- [ ] No `Role` column or property exists in `tool_catalog.json` or Tool Explorer (`ShowTools`) UI.
- [ ] Obsolete `Group` property is replaced by `SubSystem`.
- [ ] `SubSystem` includes `PC`, `LCM`, `LCM_Inventory`, `LCM_AI`, `LCM_Tools`, `HaSSD06`, and `Sandboxes`.
- [ ] Neither subsystems nor PC hardware exist as Categories.
- [ ] `Category = "Utility"` is completely eliminated.
- [ ] `Audience = "Developer"` is eliminated; replaced by the `Developer` Filter Preset.
- [ ] `Internal` is strictly an Audience, not a Filter Preset.
- [ ] `ShowTools` UI defaults to `Audience: User`.
- [ ] `ShowTools` UI provides one-click `User`, `Developer`, `Maintenance`, and `All` presets.
- [ ] `Developer` preset defaults to `NoInternals` with orthogonal column filter support to include `Internal`.
- [ ] `ShowCM` is redesigned to reflect the unified `SubSystem` taxonomy.
- [ ] SQLite database migration rebuilds and re-populates tables without redundant `role` data.
- [ ] General Readiness passes 6/6 gates across all governed repositories.
