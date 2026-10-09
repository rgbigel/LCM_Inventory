# Proposal: BUG-155 LCM Tool Explorer Tool Name and Run Action Column Interaction Correction

## Metadata
- **Proposal ID**: `155`
- **Bundle ID**: `BUG-155`
- **Origin Repo**: `LCM_Inventory` / Root (`.lcm`)
- **Target Components**:
  - `LCM_Inventory/assets/lcm-tool-explorer.js`
  - `LCM_Inventory/modules/LcmToolCatalog.psm1`
  - `LCM_Inventory/tools/scratch/User_Tools_Explorer_LCM.html`
- **Author**: Operator Directive / BUG Intake
- **Date**: 2026-09-19
- **Priority**: Normal (`M`)
- **Status**: Completed (`completed`)


---

## 1. Problem Statement
In the interactive HTML dashboard for LCM Tool Explorer (`User_Tools_Explorer_LCM.html`), the click interactions between the **TOOL NAME** column and the **ACTIONS & MODES** column were inverted:
1. Clicking the **TOOL NAME** link opened the full parameter modal (`openRunDialog(idx)`), whereas users expect clicking the tool name to directly execute the command (or only prompt if mandatory parameters are required).
2. Clicking the **`▶ Run`** button in the **ACTIONS & MODES** column performed smart direct execution (`runToolSmart(idx)`), whereas users expect the dedicated `▶ Run` action button to always open the Parameter Configuration dialog.
3. The action dropdown menu (`⋮ ▾`) contained a redundant `"⚙️ Run with Parameters..."` entry, which is unnecessary once `▶ Run` always presents the parameter dialog.

---

## 2. Proposed Architecture & Remediation

### 2.1 Tool Name Column Interaction
- Update the `.tool-name-link` click handler in `lcm-tool-explorer.js`:
  ```javascript
  onclick="window.LcmTools.runToolSmart(safeIdx)"
  ```
  - Directly dispatches execution with saved/default arguments.
  - If mandatory unfilled parameters exist, automatically routes to `openRunDialog(safeIdx)`.
  - Update tooltip to: `"Click to run tool (or configure if mandatory parameters required)"`.

### 2.2 Actions & Modes Column Interaction
- Update the `▶ Run` button in `lcm-tool-explorer.js`:
  ```javascript
  onclick="window.LcmTools.openRunDialog(safeIdx)"
  ```
  - Always opens the Two-Column Parameter Configuration & Execution Dialog (`#run-modal-overlay`).
  - Update tooltip to: `"Configure parameters and run..."`.

### 2.3 Action Dropdown Menu Streamlining
- In `LcmToolCatalog.psm1`, remove the redundant menu item from `#action-dropdown-menu`:
  ```html
  <button class="menu-item" onclick="window.LcmTools.menuAction('run_params')">⚙️ <strong>Run with Parameters...</strong></button>
  ```
- The dropdown menu cleanly retains:
  - `❓ Tool Help (-h in Notepad)`
  - `📋 Copy CLI Command`
  - `🔍 Inspect Details & Deps`
  - `💻 Show / Edit Code (IDE)`
  - `✏️ Rename Tool & Alias...`
  - `🧹 Cleanup Logs & History...`
  - `📦 Archive Tool`
  - `🗑️ Delete Tool`

---

## 3. Verification Plan
1. Rebuild tool catalog: `pwsh LCM_Inventory/tools/Show-Tools.ps1 -NoLaunch`.
2. Verify in `lcm-tool-explorer.js` and `User_Tools_Explorer_LCM.html`:
   - Clicking tool name triggers `runToolSmart`.
   - Clicking `▶ Run` triggers `openRunDialog`.
   - Action dropdown menu does not contain duplicate `Run with Parameters...`.
3. Validate with quality gate suite.
