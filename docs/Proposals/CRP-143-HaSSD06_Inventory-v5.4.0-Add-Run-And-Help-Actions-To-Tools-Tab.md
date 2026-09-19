---
Proposal-ID: CRP-143
Scope: HaSSD06_Inventory
Version: v5.4.0
Affected-Repos: [HaSSD06_Inventory, .lcm]
Priority: High
Status: Open
Target Scope: Subsystem Explorer Tool Tab Integration
---

# CRP-143: Integrate Run and Help Actions in Subsystem Explorer "Tools & Active Help" Tab

## 1. Problem Statement & Motivation
In the Home Assistant Subsystem Inventory Explorer ([`Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)), **Tab 8 ("Tools & Active Help")** provides an inventory of recognized chat commands, tool script names, roles, and CLI syntax. However, unlike the central Tool Explorer ([`Show-Tools.ps1`](file:///d:/Git_Repositories/.lcm/tools/internal/Show-Tools.ps1)), it currently lacks interactive **Run** (`▶️ Run`) and **Help** (`❓ Help`) action buttons, preventing operators from directly dispatching or inspecting tool parameters from within the subsystem dashboard.

## 2. Proposed Enhancements (In Analogy to ShowTools)
1. **Interactive Run Action Column**:
   - Add a dedicated `Actions` column with `▶️ Run` button for each tool in the catalog.
   - Support click-to-run on tool script names with parameter entry and syntax validation dialog.
   - Dispatch commands to Session 1 desktop via [`Invoke-InteractiveDesktop.ps1`](file:///d:/Git_Repositories/.lcm/tools/internal/Invoke-InteractiveDesktop.ps1) / `lcm://` protocol with appropriate administrator elevation when required.
2. **Interactive Help Action**:
   - Add a `❓ Help` button to open a modal dialog displaying the parsed `-h` synopsis, parameter table, and examples for the selected tool.
3. **Log Study Action**:
   - Provide a direct link / button (`📜 Last Log`) for tools that produce logs, linking to [`Show-LastLog.ps1 -ToolName <name>`](file:///d:/Git_Repositories/.lcm/tools/internal/Show-LastLog.ps1).
4. **Consistency**:
   - Ensure the "Tools & Active Help" table conforms 100% to the LCM Standard Table Display specification (`StandardTableDisplay.css`).

## 3. Impacted Assets
- [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)
- [`HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html`](file:///d:/Git_Repositories/HaSSD06_Inventory/docs/SHOW_HA_INVENTORY.html)
