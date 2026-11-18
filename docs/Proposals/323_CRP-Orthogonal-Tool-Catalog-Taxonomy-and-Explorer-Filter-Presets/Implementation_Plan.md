# Implementation Plan: CRP-323

## Orthogonal Tool Taxonomy: SubSystem Unification, Role Absorption into Category, and Explorer Filter Presets

### Phase 1: Taxonomy Definition & Options Modernization
- [ ] Update [`LCM_Inventory/config/tool_explorer_options.json`](file:///D:/Git_Repositories/LCM_Inventory/config/tool_explorer_options.json):
  - Rename `Subsystems` to `SubSystems`: `["PC", "LCM", "LCM_Inventory", "LCM_AI", "LCM_Tools", "HaSSD06", "Sandboxes"]`.
  - Remove `Roles` array completely.
  - Set `Categories` to the 9 unified functional categories:
    - `File System & Search`
    - `Backup & Recovery`
    - `Governance & Proposals`
    - `Review & Quality Gates`
    - `Elevation & Access`
    - `Diagnostics & Telemetry`
    - `Configuration & Customization`
    - `Environment & Runtimes`
    - `Execution Gateway`
  - Set `Audiences` to `["User", "Maintenance", "Internal"]`.
- [ ] Verify UTF-8 No-BOM encoding on `tool_explorer_options.json`.

### Phase 2: Catalog Generator (`Update-ToolCatalog.ps1`) Restructuring
- [ ] Refactor classification heuristics in [`LCM_Inventory/tools/Update-ToolCatalog.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1):
  - Remove `"Role"` property from generated tool objects.
  - Rename `"Group"` property to `"SubSystem"`.
  - Classify tools into the 3 audiences: `User`, `Maintenance`, or `Internal` (eliminating `Developer`).
  - Map each tool into one of the 9 unified categories.
  - Ensure `Category = "Utility"` is completely eliminated.
- [ ] Support `SubSystem = "Sandboxes"` detection and isolation.

### Phase 3: Tool Explorer (`ShowTools`) & Control Hub (`ShowCM`) UI Redesign
- [ ] Update `ToolExplorer.html` (`ShowTools`):
  - Remove `Role` table column and dropdown filter.
  - Rename `Group` dropdown filter to `SubSystem`.
  - Add Preset Selector toolbar (`User`, `Developer`, `Maintenance`, `All`).
  - Configure `Developer` preset to default to `NoInternals` (`['User', 'Maintenance']`), while allowing the Audience column filter to opt into `Internal`.
  - Set initial launch state to `Preset: User`.
  - Render the 9 unified categories in the Category filter dropdown.
- [ ] Update `Show-ToolIntents.ps1` (`ShowTools` entrypoint):
  - Replace `-Role` parameter with `-Category` and `-Group` with `-SubSystem`.
  - Add `-Preset` parameter (`User`, `Developer`, `Maintenance`, `All`).
- [ ] Update `CM_CONTROL_HUB.html` & `Show-LcmControl.ps1` (`ShowCM`):
  - Align subsystem filtering and status rails with the unified `SubSystem` architecture (`PC`, `LCM`, `HaSSD06`, `Sandboxes`).
  - Drop references to legacy roles.

### Phase 4: SQLite Tool Catalog Migration (`tools.db`) & Dual-State Sync
- [ ] Run `Update-ToolCatalog.ps1 -Silent` to regenerate `tool_catalog.json` and all `.cmd` launchers in `DoT`.
- [ ] Create SQLite Tool Catalog Engine (`data/tools/tools.db` & `tools.sql`):
  - Implement `tools` table schema with indexes on `audience`, `subsystem`, `category`, and `short_name`.
  - Author `Sync-LcmToolCatalogDb.ps1` (and `sync_tool_catalog_db.py`) to sync `tool_catalog.json` -> `tools.db` + `tools.sql`.
- [ ] Integrate SQLite querying into `ShowTools` (`Show-ToolIntents.ps1` & `ToolExplorer.html`):
  - Read directly from `tools.db` for instant startup and preset filtering.
- [ ] Execute `Sync-LcmProposalsDb.ps1` to keep `proposals.db` in sync.
- [ ] Verify 6/6 General Readiness gates pass across all governed repositories.

### Scope Boundary / Non-Goal Notice
- **Strategy Relational Database & `ShowStrategies`**: While CRP-323 establishes the category home for Strategies and serves as the baseline for the *Tool Taxonomy, Fast Discovery & High-Performance Execution* strategic direction, implementing the `strategies` database schema, referential integrity triggers, and `ShowStrategies` display is strictly out-of-scope and is owned exclusively by **`CRP-324`**.
