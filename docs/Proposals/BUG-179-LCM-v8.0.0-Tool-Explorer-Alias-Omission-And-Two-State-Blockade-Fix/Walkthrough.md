# Walkthrough: BUG-179

```yaml
BUG-ID: BUG-179
Title: Tool Explorer Alias Omission, Subsystem Override Reversion, and Two-State Finalize Blockade Defect
Status: Completed
Date: 2026-09-26
```

---

## 1. Overview of Changes

This defect resolution fixes three intertwined problems in the Tool Explorer ecosystem:
1. **Alias `BCR` Missing**: Generated [`LCM_Inventory/Cmd/BCR.cmd`](file:///LCM_Inventory/Cmd/BCR.cmd) and enabled alias pills in both Short-Names and Source view modes.
2. **Permanent Blockade on Finalize**: Solved index derivation collision on tools sharing identical names and ensured all matching instances have their pending status and blockade removed.
3. **Subsystem Override Reversion**: Daemon `/sync_json` now handles Subsystem/Group/Domain overrides and saves them to `LCM_Inventory/config/tool_catalog_overrides.json`, preventing `Update-ToolCatalog.ps1` from reverting them.

---

## 2. Verification Results

### 2.1 Alias Discovery & Launchers
- Queried daemon REST endpoint `POST http://127.0.0.1:9876/query_all_short_names`:
  ```json
  {
    "Name": "Invoke-BeyondCompareReview.ps1",
    "Values": [
      "LCMBeyondCompareReview",
      "BCR",
      "BeyondCompareReview"
    ]
  }
  ```
- Checked launcher trampoline on disk:
  ```cmd
  @echo off
  if not defined Git_Root set "Git_Root=%~dp0..\.."
  if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
  pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-BeyondCompareReview.ps1" %*
  ```

### 2.2 Tool Explorer HTML Build
- Ran `Show-ToolsExplorer.ps1 -NoLaunch`: completed cleanly with exit code 0.
- Verified asset mirroring hash equality between `LCM_Inventory/assets/lcm-tool-explorer.js` and `LCM_Inventory/assets/lcm-tool-explorer.js`.
