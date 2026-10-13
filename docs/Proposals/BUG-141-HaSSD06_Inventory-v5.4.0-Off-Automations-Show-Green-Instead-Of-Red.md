---
Bug-ID: BUG-141
Scope: HaSSD06_Inventory
Version: 10.0.0
Affected-Repos: [HaSSD06_Inventory]
Severity: Medium
Status: Open
Root-Cause: Show-HaInventoryApp.ps1 hardcodes badge-success for all automations regardless of whether their state is 'on' or 'off'.
---

# BUG-141: Automations with State 'OFF' Incorrectly Render Green Instead of Red

## 1. Defect Summary
In the Home Assistant Subsystem Inventory Explorer ([`Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)), under **Tab 5 (Automations & Scripts)**, automations that are turned `off` (disabled / inactive) display their state badge using `badge-success` (green) instead of `badge-danger` (red).

## 2. Root Cause Analysis
In `Show-HaInventoryApp.ps1` (lines ~833–841):
```powershell
foreach ($au in $inv.automations_catalog) {
    $html += @"
        <tr>
            <td><span class="badge badge-info">Automation</span></td>
            <td><strong>$($au.name)</strong></td>
            <td class="code-cell">$($au.entity)</td>
            <td><span class="badge badge-success">$($au.state)</span></td>
        </tr>
"@
}
```
The state badge class was static (`badge-success`) rather than evaluating `$au.state`:
- `on` -> `badge-success` (Green)
- `off` -> `badge-danger` (Red)
- `unavailable` -> `badge-warning` (Amber)

## 3. Proposed Remediation
1. Update `Show-HaInventoryApp.ps1` to calculate dynamic badge styling:
   ```powershell
   $autoBadgeClass = switch ($au.state.ToLowerInvariant()) {
       'on'          { 'badge-success' }
       'off'         { 'badge-danger' }
       'unavailable' { 'badge-warning' }
       default       { 'badge-muted' }
   }
   ```
2. Regenerate [`SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html) and [`Entities_Inventory_HaSSD06.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/Entities_Inventory_HaSSD06.html).
3. Validate state rendering against live automation states in `subsystem_inventory.json`.
