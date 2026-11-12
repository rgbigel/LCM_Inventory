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

### Phase 3: Tool Explorer UI (`ToolExplorer.html` & `Show-ToolIntents.ps1`)
- [ ] Update `ToolExplorer.html`:
  - Remove `Role` table column and dropdown filter.
  - Rename `Group` dropdown filter to `SubSystem`.
  - Add Preset Selector toolbar (`User`, `Developer`, `Maintenance`, `All`).
  - Configure `Developer` preset to default to `NoInternals` (`['User', 'Maintenance']`), while allowing the Audience column filter to opt into `Internal`.
  - Set initial launch state to `Preset: User`.
  - Render the 9 unified categories in the Category filter dropdown.
- [ ] Update `Show-ToolIntents.ps1` parameter sets to replace `-Role` with `-Category` and `-Group` with `-SubSystem`.

### Phase 4: Ledger & Database Synchronization
- [ ] Run `Update-ToolCatalog.ps1 -Silent` to regenerate `tool_catalog.json` and all `.cmd` launchers in `DoT`.
- [ ] Execute `Sync-LcmProposalsDb.ps1` to update SQLite `proposals.db` and commit `proposals.sql`.
- [ ] Verify 6/6 General Readiness gates pass across all governed repositories.
