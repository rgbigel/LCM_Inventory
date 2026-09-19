# Proposal: CRP-150 Automations & Scripts Interactive Action Suite (Toggle, YAML Edit, Delete, Rename)

## Metadata
- **Proposal ID**: `150`
- **Bundle ID**: `CRP-150`
- **Origin Repo**: `HaSSD06_Inventory`
- **Target Component**: [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1), [`HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1)
- **Author**: Operator Directive / CRP Intake
- **Date**: 2026-09-19
- **Priority**: High (`H`)
- **Status**: Suggested / Open

---

## 1. Requirement & User Intent
In `SHOW_HA_INVENTORY.html` under Tab 5 (Automations & Scripts), operator requires full interactive lifecycle actions directly in the table:
1. **Change State (Toggle On / Off)**:
   - Enable/disable automations and run/stop scripts via REST API (`/api/services/automation/turn_on`, `/api/services/automation/turn_off`, `/api/services/script/turn_on`, etc.) and local REST daemon / `lcm://` dispatch.
   - Interactive toggle switch / action button with optimistic UI state update and toast feedback.
2. **Edit Automation / Script YAML**:
   - Integrated YAML inspection & editor subpanel modal.
   - Deep links to native Home Assistant YAML editor (`/config/automation/edit/<id>`, `/config/script/edit/<id>`).
   - Copy YAML payload to clipboard.
3. **Delete Automation / Script**:
   - Dedicated deletion modal with safety confirmation prompt, dependency scanner (checks whether other automations, scripts, or dashboards reference this entity), and REST/WebSocket delete dispatch / HA deep-link.
4. **Rename Automation / Script**:
   - Direct integration into our existing `#entityRenameModal` and [`Invoke-HaRenameCascade.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1) engine to cascade renaming across references and ledgers.

---

## 2. Technical Architecture & Component Design

### 2.1 Tab 5 Table Actions
- Add dedicated **Actions** column in `#table-automations` with interactive buttons:
  - `⚡ Toggle` (Quick turn on / turn off)
  - `📝 YAML` (Open YAML viewer/editor subpanel)
  - `✏️ Rename` (Open `#entityRenameModal` pre-populated)
  - `🗑️ Delete` (Open `#automationDeleteModal` with dependency audit)

### 2.2 Interactive Modals
1. **`#automationYamlModal`**:
   - Displays formatted YAML configuration for the selected automation/script.
   - Action buttons: `📋 Copy YAML`, `🌐 Open in HA Editor`, `💾 Save Changes (HA REST/Daemon)`.
2. **`#automationDeleteModal`**:
   - Displays entity details, friendly name, and reverse-dependency references.
   - Confirmation safety barrier.
   - Action buttons: `🗑️ Confirm Delete (HA REST/Daemon)`, `Cancel`.

### 2.3 Dispatching & HA API Integration
- Uses standard LCM dispatch mechanism:
  - Direct HTTP to local REST daemon (`http://127.0.0.1:9876/execute` or `/ha/api/services/...`)
  - Protocol fallback: `lcm://run?...` or HA native URL redirect.

---

## 3. Verification Plan
- Validate modal triggering for Toggle, YAML Edit, Delete, and Rename.
- Verify reverse reference scanner triggers in Deletion modal.
- Verify `Show-HaInventoryApp.ps1 -NoLaunch` compiles valid HTML.
- Run `Test-RepoReadiness.ps1` to ensure 5/5 quality gates pass.
