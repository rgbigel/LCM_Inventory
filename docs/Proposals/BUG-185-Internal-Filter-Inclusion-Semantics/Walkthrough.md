# Walkthrough: BUG-185 Tool Explorer Internal Button Filter Inversion and Empty Catalog Defect

## Verification Checklist

1. **Verify Default Initial View & Full Catalog Access**:
   - Open `SHOW_TOOLS.html`.
   - All dropdowns (`Group`, `Audience`, `Role`, etc.) are set to `All`.
   - Tools 1 through 8 (`Show-HaAuthDialog.ps1`, `Show-HaInventory.ps1`, `Invoke-HaUpdateGate.ps1`, etc.) are fully visible.
   - `Intern` button is in default unclicked state.

2. **Verify Metric Card Counter**:
   - Top-left card `#card-all` displays `Total / Selected Tools` with value `201 / 201`.
   - Applying any filter (e.g. typing a search query or selecting a group) updates the counter dynamically (e.g. `201 / 99`).

3. **Verify Toolbar Icons & Labels**:
   - Icons for `Print / PDF` (`🖨️`), `ShowTools` (`📊`), `Intern` (`🔒`), `Bulk Assign` (`⚡`), `Reset All Filters` (`↺`), `Save` (`💾`), `Replace` (`🔄`), `Delete` (`🗑️`) are cleanly rendered at 16px.
   - Label `Presets:` is not forced uppercase.
   - Table header displays `Tool Name` (with space).
   - Toolbar button displays `Intern` (not `Int.`).

4. **Verify Dynamic Column Widths & Mode Toggle**:
   - In default Short mode, button displays `💬 Mode: Short` and table header shows `Tool Name`.
   - Click `Mode: Short` to switch to `📁 Mode: Code`.
   - Verify button updates to `📁 Mode: Code` and table header updates to `Source File`.
   - Verify the `Source File` column automatically widens to fit longer filenames without stretching out across the entire screen (constrained by `maxWidth`).
   - Select a wide option in a dropdown (e.g. `Category: JIT Authentication` or `Group: SystemConfiguration`) and verify the column header automatically widens to fit the text.

5. **Verify Horizontal Scrollbar**:
   - Verify the horizontal scrollbar is permanently visible on the `.table-container`.
   - Scrolling horizontally scrolls smoothly without header displacement.

6. **Verify Reset All Filters**:
   - Click `↺ Reset All Filters`.
   - Verify all dropdown selectors are set to `All`.
   - Verify the search query input is cleared.
   - Verify all tools (including tools 1 through 8) are displayed.

7. **Verify 201 Tool Parity & Zero Off-By-One**:
   - Verify the counter shows `201 / 201`.
   - Scroll to the bottom of the table: verify the final row has index `# 201` (`WorkspacePush` / `Invoke-WorkspacePush.ps1`).
   - Verify there are no skipped indices.

8. **Verify Viewport Lock & Live Window Narrowing (Auto-Shrink)**:
   - Position window at the very top: verify the top controls (Title, Metrics, Search, Presets) and the table header (`# All Tools`) remain 100% frozen.
   - Verify the horizontal scrollbar sits directly at the bottom of the viewport and never moves off-screen.
   - Drag the window edge to narrow the browser width: verify the table auto-shrinks dynamically without requiring a page refresh.

9. **Verify Single HTML Output Architecture**:
   - Verify only a single authoritative file `SHOW_TOOLS.html` exists in `LCM_Inventory/scratch/` and `LCM_Inventory/tools/scratch/`.
   - Verify all obsolete alias/mode HTML files (`User_Tools_Explorer_LCM.html`, `Developer_Tools_Explorer_LCM.html`, `Dev_Tools_Explorer_LCM.html`, `Tools_Explorer_LCM.html`) are purged.
   - Verify Print Preview Atom references `SHOW_TOOLS.html`.
