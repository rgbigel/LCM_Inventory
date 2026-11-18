# Implementation Plan: BUG-325

## Proposed Changes

### LCM_Inventory

#### [modules/LcmToolCatalog.psm1](file:///D:/Git_Repositories/LCM_Inventory/modules/LcmToolCatalog.psm1)
- Standardize script tag order to `<script id="lcm-display-data" type="application/json">$displayPayload</script>`.
- Update metadata version to `10.2.2` and timestamp.

#### [src/do/daemon.go](file:///D:/Git_Repositories/LCM_Inventory/src/do/daemon.go)
- Enhance `handleDisplays` to recognize both attribute orders in `<script ... id="lcm-display-data" ...>`.
- Recompile `do.exe` and deploy to `DoT/do.exe`.

#### [data/artifacts/SHOW_TOOLS.html](file:///D:/Git_Repositories/LCM_Inventory/data/artifacts/SHOW_TOOLS.html)
- Re-render artifact via `Show-ToolsExplorer.ps1 -NoLaunch`.

## Verification Plan
- Run Pester tests: `Invoke-Pester tests/LcmDisplayFreshness.Tests.ps1`.
- Verify REST endpoint: `GET /displays/data/tools` returns 317 tools.
- Verify status: `GET /displays/status/tools` returns `state: Current`.
