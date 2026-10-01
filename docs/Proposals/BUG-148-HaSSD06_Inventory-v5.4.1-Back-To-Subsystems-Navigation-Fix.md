---
Proposal-ID: BUG-148
Scope: HaSSD06_Inventory
Version: v5.4.1
Affected-Repos: [HaSSD06_Inventory, LCM_Inventory]
Priority: High
Status: In_Progress
Target Scope: Subsystem Explorer Breadcrumb Navigation & Hub Link Resolution
---

# BUG-148: HA_Inventory Navigation Failure on "Back to Subsystems" Button

## 1. Problem Statement & Root Cause
In `Show-HaInventoryApp.ps1` (and `SHOW_HA_INVENTORY.html`), the navigation breadcrumb button `⬅️ Back to Subsystems` was configured with:
```html
<button class="btn-back-nav" onclick="window.history.length > 1 ? window.history.back() : window.location.href='SHOW_LCM.html'" title="Return to master subsystem list">
    ⬅️ Back to Subsystems
</button>
```
When `SHOW_HA_INVENTORY.html` is opened directly in a browser (e.g. Zen Browser) in a new tab, `window.history.back()` has no previous history or fails, triggering the fallback `window.location.href='SHOW_LCM.html'`.

Because `SHOW_HA_INVENTORY.html` resides in `D:\Git_Repositories\HaSSD06_Inventory\docs\`, the relative link `SHOW_LCM.html` resolves to `D:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_LCM.html`, which does not exist, causing browser error:
`File not found: Zen can’t find the file at D:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_LCM.html.`

## 2. Proposed Solution
1. **Implement `navigateBackToSubsystems()` Navigation Handler**:
   - Inspect `document.referrer`: If the user navigated from an existing dashboard (e.g. `SHOW_SUBSYSTEMS.html`, `WORKSPACE_INVENTORY_VIEWER.html`, `SHOW_LCM.html`, `SHOW_TOOLS.html`), navigate back cleanly via `window.history.back()`.
   - Provide deterministic relative and REST daemon fallback:
     - Target 1: `../../LCM_Inventory/docs/SHOW_WORKSPACE_INVENTORY.html` / `WORKSPACE_INVENTORY_VIEWER.html` (Authoritative Subsystems & Repositories list)
     - Target 2: `../../.lcm/scratch/SHOW_SUBSYSTEMS.html` / `../../.lcm/scratch/SHOW_LCM.html`
     - Target 3: Dispatches `Show-WorkspaceInventoryApp.ps1` or `Show-Subsystems.ps1` via local REST Daemon / `lcm://` protocol.
2. **Synchronize Navigation Invariants**:
   - Update `Show-HaInventoryApp.ps1` to embed `navigateBackToSubsystems()`.
   - Recompile `docs/SHOW_HA_INVENTORY.html` and `docs/Entities_Inventory_HaSSD06.html`.
   - Ensure `Show-Subsystems.ps1` and `Show-LCM.ps1` outputs in `.lcm/scratch/` are synced.

## 3. Impacted Assets
- [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)
- [`HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html)
- [`HaSSD06_Inventory/docs/Entities_Inventory_HaSSD06.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/Entities_Inventory_HaSSD06.html)
