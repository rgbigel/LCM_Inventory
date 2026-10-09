# Bug Fix Proposal: BUG-178

```yaml
BUG-ID: BUG-178
Title: Tool Explorer Approved Verb Naming, Catalog Deduplication, Self-Tool Filtering, and Scrollbar Hardening
Scope: .lcm, LCM_Inventory, Tool Explorer UI, Tool Catalog Sync Engine
Baseline-Version: v8.0.0
Author: Rolf, Antigravity AI Assistant
Date: 2026-09-26
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: High
Impacted-Repositories:
  - Git_Repositories
  - LCM_Inventory
```

---

## 1. Problem Statement & Root Cause Analysis

Following the deployment of CRP-177 and interactive user reorganization, several critical operational defects and architectural ambiguities emerged:

1. **Tool Explorer Naming Ambiguity & Verb Non-Compliance (`RULE-PS-002`)**:
   - The tool name `ShowTools` was overloaded in three conflicting ways: (a) the script runner itself, (b) the self-tool entry within the table, and (c) the toolbar button and preset filtering `Show-*` visual displays.
   - An interactive rename to `ToolsExplorer.ps1` introduced a violation of PowerShell Standards Policy (`RULE-PS-002`), which mandates Microsoft-approved verbs (`Get-Verb`). `ToolsExplorer` lacks an approved verb.
   - Script launchers in `LCM_Inventory/Cmd/` required canonicalization to `ToolExplorer.cmd` while preserving backward compatibility for `ShowTools.cmd`.

2. **Dual-Catalog State Desynchronization**:
   - Two physical `tool_catalog.json` files existed on disk: the active authoritative catalog `LCM_Inventory\config\tool_catalog.json` (regularly updated) and a stale legacy copy `LCM_Inventory\tools\tool_catalog.json` (outdated from September 11).
   - In fallback scenarios, tools fell back to the obsolete copy, causing reverted states and missing tool definitions.

3. **Two-State Lifecycle "Blocked" State Misunderstanding & Storage Decoupling**:
   - In-place cell edits to Subsystem in the UI marked tools with `IsBlocked = true` ("Blocked" status).
   - When the file on disk was renamed from `Show-Tools.ps1` to `ToolsExplorer.ps1`, the browser's `localStorage` overrides keyed by filename decoupled from the new file stem, causing staged edits to disappear.

4. **Self-Tool Pollution in Tool Catalog**:
   - Tool Explorer listed its own runner script as a selectable row in the catalog, creating unnecessary clutter and confusion when running inside the dashboard.

5. **Disappearance of Horizontal Scrollbar in Tool Explorer**:
   - Compacted UI controls in CRP-177 allowed the 11-column table to fit within wide viewports without horizontal overflow, causing `overflow-x: auto` to automatically hide the scrollbar.
   - On screens under 1600px, columns like `Description` and `Subsystem` wrapped tightly rather than scrolling.
   - Firefox / Zen Browser overlay scrollbars had virtually invisible contrast (`#30363d` on `#161b22`).

---

## 2. Technical Modifications

### 2.1 Approved-Verb Realignment & Command Trampolines
- **Canonical Script**: [`Show-ToolsExplorer.ps1`](file:///LCM_Inventory/tools/Show-ToolsExplorer.ps1) with `[Alias('ShowTools', 'ToolsExplorer', 'ToolExplorer')]`.
- **Forwarder**: [`LCM_Inventory/tools/ToolsExplorer.ps1`](file:///LCM_Inventory/tools/ToolsExplorer.ps1) delegating execution directly to `Show-ToolsExplorer.ps1`.
- **Command Trampolines**:
  - [`LCM_Inventory/Cmd/ToolExplorer.cmd`](file:///LCM_Inventory/Cmd/ToolExplorer.cmd)
  - [`LCM_Inventory/Cmd/ToolsExplorer.cmd`](file:///LCM_Inventory/Cmd/ToolsExplorer.cmd)
  - [`LCM_Inventory/Cmd/ShowTools.cmd`](file:///LCM_Inventory/Cmd/ShowTools.cmd)

### 2.2 Stale Duplicate Catalog Deletion
- Deleted obsolete artifact `LCM_Inventory/tools/tool_catalog.json`.
- Updated [`Sync-ToolSymlinks.ps1`](file:///LCM_Inventory/tools/Sync-ToolSymlinks.ps1) fallback path to `LCM_Inventory/config/tool_catalog.json`.
- Hardened [`LcmToolCatalog.psm1`](file:///LCM_Inventory/modules/LcmToolCatalog.psm1) candidate discovery paths.

### 2.3 Catalog Generator Metadata Updates
- Updated `$metadataOverrides` in [`Update-ToolCatalog.ps1`](file:///LCM_Inventory/tools/Update-ToolCatalog.ps1) mapping `Show-ToolsExplorer.ps1`, `ToolsExplorer.ps1`, and `Show-Tools.ps1` to ShortName `ToolExplorer`.
- Added stem identifiers to heuristic `NoExit` whitelist.

### 2.4 Self-Tool Exclusion in Dashboard UI
- Updated `lcm-tool-explorer.js` (both `LCM_Inventory/assets` and `LCM_Inventory/assets`) filtering out self-tool stems (`Show-ToolsExplorer`, `ToolsExplorer`, `ShowTools`) during initial data loading and filter passes.

### 2.5 Table Sizing & Scrollbar Contrast Hardening
- Enforced `min-width: 1560px !important;` on `table` in [`LCMToolCatalog.css`](file:///LCM_Inventory/assets/LCMToolCatalog.css).
- Configured 10px scrollbar height with high-contrast thumb (`var(--text-muted)` default, `var(--accent)` on hover) and explicit `scrollbar-color: var(--accent) var(--bg-secondary) !important;`.
- Fixed missing `</tbody>` tag closure in `LcmToolCatalog.psm1`.

---

## 3. Verification & Compliance
- `pwsh LCM_Inventory/tools/Update-ToolCatalog.ps1` completed with 0 errors.
- `Show-ToolsExplorer.ps1 -NoLaunch` successfully generated the interactive HTML catalog.
- Conforms to `RULE-PS-002` (Approved Verbs), `RULE-PS-008` (Metadata Headers), `RULE-PS-009` (Audit Logging), and `RULE-PS-010` (Help Handling).
