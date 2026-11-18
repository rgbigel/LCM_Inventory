# Walkthrough: CRP-180

```yaml
CRP-ID: CRP-180
Title: Tool Explorer Ergonomics: Column Realignment, Bulk Finalize, and Precompiled Dynamic Taxonomy Options
Status: Completed
Date: 2026-10-13
```

---

## 1. Summary of Changes

This Change Request Proposal delivers five major ergonomic and functional enhancements to the LCM Tool Explorer:

1. **New 11-Column Order**:
   - `#`
   - `ToolName`
   - `Actions & Modes`
   - `Subsys`
   - `Role`
   - `Description`
   - `Category`
   - `Audience`
   - `Env.`
   - `Admin`
   - `NoExit`

2. **Refined Row Action Buttons & Blocked Display**:
   - Blocked rows display exclusively the `⛔` symbol without text clutter.
   - `Reset` button text is styled in red (`#f85149`).
   - `Set` button text is styled in green (`#3fb950`).

3. **Bulk Unblock (`SetAll`)**:
   - Added `SetAll` green button in the Actions column header filter row.
   - Finalizes all currently blocked rows across the entire tool catalog in one click.

4. **Precompiled Taxonomy Options & Dynamic `+ New...` Extension**:
   - Subsystem, Role, and Category dropdowns are precompiled during HTML generation and saved to `LCM_Inventory/config/tool_explorer_options.json`.
   - Selecting `+ New...` prompts the operator for a new value, automatically persists it through the daemon REST API (`POST /add_explorer_option`), updates in-memory options, and sets the value immediately.

5. **Guaranteed Horizontal Scrollbar**:
   - Forced `overflow-x: scroll !important` on `.table-container` with table `min-width: 1800px !important`.
   - Styled high-contrast 12px accent scrollbar visible on all display resolutions.

---

## 2. Verification Results

### 2.1 Tool Explorer Build & Generation
- Executed `Show-ToolsExplorer.ps1 -NoLaunch`: exit code 0.
- Verified `LCM_Inventory/config/tool_explorer_options.json` generated with accurate catalog values for Subsystems, Roles, and Categories.

### 2.2 Asset Hash Equality
- Verified identical SHA-256 hashes between `LCM_Inventory/assets/` and `LCM_Inventory/assets/` for both `LCMToolCatalog.css` and `lcm-tool-explorer.js`.
