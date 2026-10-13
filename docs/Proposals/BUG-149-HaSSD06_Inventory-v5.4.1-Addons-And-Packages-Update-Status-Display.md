# Proposal: BUG-149 Add-ons & Packages Status and Semantic Update State Display

## Metadata
- **Proposal ID**: `149`
- **Bundle ID**: `BUG-149`
- **Origin Repo**: `HaSSD06_Inventory`
- **Target Component**: [`HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1), [`HaSSD06_Inventory/tools/Update-HaInventory.ps1`](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Update-HaInventory.ps1)
- **Author**: Operator Directive / BUG Intake
- **Date**: 2026-10-13
- **Priority**: High (`H`)
- **Status**: Suggested / In Progress

---

## 1. Problem Statement & Root Cause
In `SHOW_HA_INVENTORY.html` under Tab 4 (Add-ons & Packages), all items (including Home Assistant Supervisor, Home Assistant Core, Home Assistant Operating System, Matter Server, Mosquitto broker, etc.) display a red badge with the text **`OFF`**, while only Studio Code Server displays **`running`**.

### Root Cause
1. In Home Assistant, entities in the `update` domain represent software components (Core, Supervisor, OS, Supervisor Add-ons, HACS integrations, Frontend cards, and firmware).
2. The entity `state` of an `update` entity is binary:
   - `off` = **No update available; installed version is current and up-to-date**.
   - `on` = **A newer update is available and pending installation**.
   - `installing` = **An update is actively being installed**.
   - `unavailable` = **Component unreachable**.
3. `Update-HaInventory.ps1` copied the raw `state: "off"` into `data/subsystem_inventory.json`, and `Show-HaInventoryApp.ps1` mapped `"off"` directly to `badge-danger` and printed `"off"`.

---

## 2. Proposed Changes & Specifications

### 2.1 Schema & Telemetry Extraction ([Update-HaInventory.ps1](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Update-HaInventory.ps1))
- Distinguish between supervisor service states (`running`, `stopped`) and `update.*` entity states.
- Extract `installed_version`, `latest_version`, and compute semantic `status_text`:
  - `off` -> `up_to_date` ("Up to date")
  - `on` -> `update_available` ("Update available")
  - `installing` -> `installing` ("Installing")
  - `unavailable` -> `unavailable` ("Unavailable")
- Add automatic category classification:
  - `Core Subsystem` (`update.home_assistant_core_update`)
  - `Supervisor Subsystem` (`update.home_assistant_supervisor_update`)
  - `Operating System` (`update.home_assistant_operating_system_update`)
  - `Supervisor Add-on` (`addon_*`, `matter_server`, `go2rtc`, `mosquitto`, `vnc`, `filebrowser`, `samba`, `srat`)
  - `HACS / Custom Integration` (`alexa_media_player`, `tuya_local`, `eufy_security`, `hacs`, `webrtc_camera`, etc.)
  - `Lovelace Card` (`*_card_update`)
  - `Device Firmware` (`*_firmware`, `fritz_os`, `fp300`)

### 2.2 Dashboard Presentation ([Show-HaInventoryApp.ps1](file:///d:/Git_Repositories/HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1))
- Update `#table-addons` headers and columns:
  1. **Component / Package**: Title, icon/badge
  2. **Category**: Styled badge (`Core Subsystem`, `Add-on`, `HACS Integration`, etc.)
  3. **Tracking Entity / Slug**: Entity ID
  4. **Installed Version**: Current installed release
  5. **Latest Version**: Upstream latest release
  6. **Operational Status**:
     - `🟢 Up to date` (`badge-success`)
     - `🟡 Update Available (vX.Y.Z)` (`badge-warning`)
     - `🔵 Installing` (`badge-info`)
     - `🔴 Stopped` (`badge-danger`)
     - `⚪ Unavailable` (`badge-muted`)
- Add aligned column filters and sort headers.

---

## 3. Verification Plan
- Run `pwsh tools/Update-HaInventory.ps1` (or verify extraction logic).
- Run `pwsh tools/Show-HaInventoryApp.ps1 -NoLaunch` to compile HTML.
- Verify that Home Assistant Core, Supervisor, OS, and Add-ons display green `🟢 Up to date` badges.
- Run `pwsh tools/Test-RepoReadiness.ps1` to ensure 5/5 quality gates pass.
