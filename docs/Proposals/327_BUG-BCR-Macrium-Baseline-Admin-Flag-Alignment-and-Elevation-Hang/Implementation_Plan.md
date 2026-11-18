# Implementation Plan: BUG-327

## Scope
Remediate catalog admin flags and elevate worker dispatch via Port 9876 Desktop Daemon.

## Proposed Steps

### Step 1: Update Tool Catalog
- In `LCM_Inventory/config/tool_catalog.json`:
  - Set `"Admin": true` on `Invoke-MacriumDailyBcrBaseline.ps1`.
  - Set `"Admin": true` on `Invoke-MacriumBcrReview.ps1`.
- In `LCM_Inventory/data/tools/tools.sql`:
  - Update `admin = 1` for `Invoke-MacriumDailyBcrBaseline.ps1` and `Invoke-MacriumBcrReview.ps1`.
- Run `LCM_Inventory/tools/Update-ToolCatalog.ps1` to regenerate `DoT/BCR.cmd` and `DoT/MacriumDailyBcrBaseline.cmd`.

### Step 2: Update `Invoke-MacriumDailyBcrBaseline.ps1`
- Refactor the elevated worker launch block (lines 1083-1120) to check if Port 9876 Desktop Daemon is online.
- When daemon is online, dispatch the worker script execution via POST to `http://127.0.0.1:9876/execute` with `elevated = $true` and `sync = $true`.
- If daemon is offline, fall back to `Start-Process -Verb RunAs`.

### Step 3: Verification
- Verify `DoT/BCR.cmd` has `net session` elevation check.
- Test mounting today's baseline partition without UAC prompt or hanging.
- Verify BCR review window opens properly.

