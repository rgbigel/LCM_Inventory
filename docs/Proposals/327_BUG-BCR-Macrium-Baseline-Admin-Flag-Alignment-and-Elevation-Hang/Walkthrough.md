# Walkthrough: BUG-327

## Progress & Verification

### Status: Verified & Completed

1. **Tool Catalog Admin Flags Aligned**:
   - `Invoke-MacriumDailyBcrBaseline.ps1`: Changed `Admin` to `true` in `tool_catalog.json` and `tools.sql`.
   - `Invoke-MacriumBcrReview.ps1`: Changed `Admin` to `true` in `tool_catalog.json` and `tools.sql`.
   - Executed `Update-ToolCatalog.ps1`: Successfully regenerated `DoT/BCR.cmd` and `DoT/MacriumDailyBcrBaseline.cmd` with automatic administrative elevation checks (`net session` -> `call "%~dp0do.cmd" -Command "%~nx0 %*" -Elevated`).

2. **Session 1 Desktop Daemon Priority Integration**:
   - In `LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1`:
     - Added automatic pre-check for the Port 9876 Session 1 Desktop Daemon before falling back to local `Start-Process -Verb RunAs`.
     - When the daemon is online, worker mounting commands are dispatched directly to `http://127.0.0.1:9876/execute` with `elevated = $true` and `sync = $true`.
     - Corrected `Set-LcmRegistryValue` daemon endpoint from `/api/action` to `/execute`, properly executing registry key/value updates.

3. **Live Verification Results**:
   - Executed baseline mounting in non-elevated context:
     ```
     [INFO] Dispatching elevated Macrium worker via Session 1 Desktop Daemon (Port 9876).
     [INFO] Elevated Macrium worker completed via Desktop Daemon.
     [INFO] Mounted 'B:\Backups\D4P3+4-WDB850-AD\...-04-04.mrimgx' at F:
     ```
   - Baseline partition successfully mounted at `F:\Git_Repositories` in ~8 seconds with zero UAC prompt and zero hanging.
   - Executed `Invoke-MacriumBcrReview.ps1 -CRP CRP-326`:
     ```
     [INFO] Mounted candidate at F: matches today's completed backup. Reusing via fast-path.
     [INFO] Dispatched Beyond Compare 5 to Session 1 via Desktop Daemon.
     ```
   - Beyond Compare 5 opened live in Session 1 (PID 13688).
