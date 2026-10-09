# Walkthrough: BUG-178

```yaml
BUG-ID: BUG-178
Title: Tool Explorer Approved Verb Naming, Catalog Deduplication, Self-Tool Filtering, and Scrollbar Hardening
Date: 2026-09-26
Status: Completed
```

---

## 1. Summary of Changes

This bug fix resolves the naming, state persistence, and display defects in the LCM Tool Explorer:

1. **PowerShell Approved Verb Alignment**:
   - [`Show-ToolsExplorer.ps1`](file:///LCM_Inventory/tools/Show-ToolsExplorer.ps1) is now the authoritative script conforming to `RULE-PS-002`.
   - Command aliases (`ToolExplorer`, `ToolsExplorer`, `ShowTools`) are fully supported via trampolines in `LCM_Inventory/Cmd/`.

2. **Deduplication of Tool Catalog**:
   - The stale September 11 copy `LCM_Inventory/tools/tool_catalog.json` was purged.
   - All tools and runtime scripts now read strictly from the single source of truth: [`LCM_Inventory/config/tool_catalog.json`](file:///LCM_Inventory/config/tool_catalog.json).

3. **Self-Tool Exclusion**:
   - The Tool Explorer UI no longer displays its own runner script within the interactive tools table.

4. **Horizontal Scrollbar Restored & Hardened**:
   - `table` min-width is locked at `1560px !important;` to ensure column content is never squished or forced into awkward vertical wrapping.
   - Scrollbar thumb styling now features high-contrast borders and an accent hover color.

---

## 2. Verification Evidence

### 2.1 Update-ToolCatalog Execution
```powershell
pwsh -File LCM_Inventory/tools/Update-ToolCatalog.ps1
```
Output:
- Persisted canonical catalog: `D:\Git_Repositories\LCM_Inventory\config\tool_catalog.json`
- Generated 206 short-name `.cmd` launchers.
- Status: `COMPLETED`.

### 2.2 Dashboard Generation Check
```powershell
pwsh -File LCM_Inventory/tools/Show-ToolsExplorer.ps1 -NoLaunch
```
Output:
- `Show-ToolsExplorer` completed successfully with code 0.
- Dashboard generated at `LCM_Inventory/tools/scratch/Tools_Explorer_LCM.html`.
