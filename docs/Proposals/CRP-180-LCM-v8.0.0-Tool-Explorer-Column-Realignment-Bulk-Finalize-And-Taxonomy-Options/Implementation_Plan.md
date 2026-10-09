# Implementation Plan: CRP-180

```yaml
CRP-ID: CRP-180
Title: Tool Explorer Ergonomics: Column Realignment, Bulk Finalize, and Precompiled Dynamic Taxonomy Options
Scope: .lcm, LCM_Inventory, Tool Explorer UI, Tool Catalog Sync Engine, LCM Desktop Daemon
Status: Completed
Date: 2026-09-26
```

---

## 1. Objectives
1. Realize 11-column order: `#` / `ToolName` / `Actions & Modes` / `Subsys` / `Role` / `Description` / `Category` / `Audience` / `Env.` / `Admin` / `NoExit`.
2. Update blocked status indicator to single red "no entry" symbol (`⛔`) without text.
3. Update row action buttons: `Reset` in red `#f85149`, `Set` in green `#3fb950`.
4. Provide `SetAll` header button to bulk finalize/unblock all blocked tools.
5. Derive dropdown taxonomy options during catalog build, persist to `LCM_Inventory/config/tool_explorer_options.json`, and support dynamic addition via `+ New...` backed by the daemon endpoint `POST /add_explorer_option`.
6. Enforce persistent horizontal scrollbar with `overflow-x: scroll !important` and `min-width: 1800px !important`.

---

## 2. Execution Steps

### Phase 1: Daemon Dynamic Taxonomy Endpoint
- [x] Register route `POST /add_explorer_option` in `LcmDesktopDaemon.ps1`.
- [x] Implement `DaemonActionController.AddExplorerOption` to append and persist options to `tool_explorer_options.json`.

### Phase 2: HTML Generator & Taxonomy Compilation (`LcmToolCatalog.psm1`)
- [x] Extract unique Subsystems, Roles, and Categories into `tool_explorer_options.json`.
- [x] Realign `<th>` headers and filter row elements to the new 11-column layout.
- [x] Insert `SetAll` button and `↺ Reset` into the Actions filter cell.
- [x] Populate filter selects with precompiled options plus `+ New...`.
- [x] Embed `window.__LCM_OPTIONS__ = $optionsJson;`.

### Phase 3: Client Table Rendering & Interactivity (`lcm-tool-explorer.js`)
- [x] Realign `renderTable` row generation cells to match the 11-column order.
- [x] Render blocked status with standalone `⛔` icon.
- [x] Style `Reset` (red) and `Set` (green) buttons.
- [x] Implement `finalizeAllBlocked()`, `handleSelectFilterChange()`, and `handleCellEditSelectChange()`.
- [x] Populate in-cell editors dynamically from `window.__LCM_OPTIONS__` with `+ New...`.
- [x] Mirror JS to `LCM_Inventory/assets/lcm-tool-explorer.js`.

### Phase 4: CSS Scrollbar Hardening (`LCMToolCatalog.css`)
- [x] Set `.table-container` to `overflow-x: scroll !important;`.
- [x] Set `table` to `min-width: 1800px !important;`.
- [x] Mirror CSS to `LCM_Inventory/assets/LCMToolCatalog.css`.

### Phase 5: Verification & Governance
- [x] Run `Show-ToolsExplorer.ps1 -NoLaunch` to compile dashboard.
- [x] Verify hash equality across mirrored assets.
- [x] Register `CRP-180` in `LCM_Inventory/data/proposals/proposals.json`.
- [x] Commit changes to `LCM_Inventory` and root `Git_Repositories`.
