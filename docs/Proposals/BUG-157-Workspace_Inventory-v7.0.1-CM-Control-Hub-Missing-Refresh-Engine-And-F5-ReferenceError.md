# Proposal: BUG-157 CM Control Hub Missing Refresh Engine & F5 Keydown ReferenceError Remediation

## Metadata
- **Proposal ID**: `157`
- **Bundle ID**: `BUG-157`
- **Origin Repo**: `LCM_Inventory`
- **Target Components**:
  - `LCM_Inventory/assets/CM_CONTROL_HUB.html`
  - `LCM_Inventory/data/artifacts/CM_CONTROL_HUB.html`
  - `LCM_Inventory/scratch/CM_CONTROL_HUB.html`
  - `LCM_Inventory/tools/Show-CmControlHub.ps1`
- **Author**: Operator Directive / BUG Intake
- **Date**: 2026-10-13
- **Priority**: High (`H`)
- **Status**: Completed (`completed`) / Pushed (`pushed`)

---

## 1. Problem Statement
When operators interact with the **LCM Configuration Management Control Hub** single-page web dashboard:
1. **Silent F5 Lockout & ReferenceError**: The global window event listener intercepted `F5` keydown events via `e.preventDefault()`, but invoked an undefined function `refreshData()`. This raised an unhandled `Uncaught ReferenceError: refreshData is not defined` in the browser console and prevented the browser from reloading the page or updating ledger data.
2. **Missing UI Refresh Control**: The top navigation bar (`.top-actions`) lacked a visual **Refresh** button, requiring manual URL manipulation or command-line re-execution of `Show-CmControlHub.ps1` to observe recent state transitions or push milestones.
3. **Static Snapshot Staleness**: Under local file protocol execution (`file:///.../CM_CONTROL_HUB.html`), normal page reloads re-read the static compile-time snapshot unless dynamic fetching is attempted against the live `proposals.json` and `cm_activity.log` files.

---

## 2. Root Cause Analysis
In `LCM_Inventory/assets/CM_CONTROL_HUB.html`:
- Line 1311 contained `if (e.key === "F5") { e.preventDefault(); refreshData(); }`, yet `refreshData` was never declared or implemented in the script scope.
- `.top-actions` container contained buttons for theme toggling, supervision hub navigation, CRP dates, git pushing, logs, and printing, but omitted a primary refresh action.

---

## 3. Implemented Remediation

### 3.1 Primary Toolbar Refresh Control
Added an interactive, accessible **`[🔄 Refresh]`** button to `.top-actions` in the main dashboard header:
```html
<button class="btn btn-primary" id="btn-refresh-hub" onclick="refreshHubData(true)" title="Reload latest proposal ledger, statuses, and logs (F5 / Ctrl+R)">
  <span id="refresh-hub-icon">🔄</span> <span id="refresh-hub-label">Refresh</span>
</button>
```

### 3.2 Dynamic Asynchronous Refresh Engine (`refreshHubData`)
Implemented `refreshHubData(manual = true)` supporting a 2-tier update strategy:
1. **Dynamic Asynchronous Fetch**:
   - Queries `../proposals/proposals.json`, `../../data/proposals/proposals.json`, or local REST endpoints (`http://127.0.0.1:9876/api/proposals`) with `cache: 'no-store'`.
   - Queries `../../logs/cm_activity.log` for live audit log traces.
   - On successful fetch:
     - Updates in-memory `proposalsData` and `activeLogText`.
     - Dynamically triggers `populateScopeDropdown()`, `updateMetricCards()`, and `renderTable()` in-place.
     - Updates the compilation subtitle with the exact live refresh timestamp (`Refreshed: hh:mm:ss`).
     - Emits live feedback ticker and console output.
2. **Browser Sandbox Fallback**:
   - If local `file://` security restrictions disallow cross-directory dynamic fetch, safely executes `window.location.reload()` to reload the latest compiled on-disk snapshot.

### 3.3 Keybinding & Animation Hardening
- Bound both **`F5`** and **`Ctrl+R`** to `refreshHubData(true)` with complete `try/catch` safety.
- Aliased `refreshData()` to `refreshHubData(true)`.
- Added CSS `.spin-icon` micro-animation during active refresh cycles.

---

## 4. Verification & Validation
1. **Headless & Interactive Browser Execution**:
   - Validated that clicking `[🔄 Refresh]` or pressing `F5` / `Ctrl+R` triggers `refreshHubData(true)` without throwing console errors.
   - Verified metric cards, column filter selectors, and the 156-item proposal table re-render dynamically.
2. **Artifact Re-compilation**:
   - Re-ran `Show-CmControlHub.ps1 -NoLaunch` to regenerate `data/artifacts/CM_CONTROL_HUB.html`.
