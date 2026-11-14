# Walkthrough: CRP-246

```yaml
CRP-ID: CRP-246
Title: Consolidate Canonical Rules in LCM_AI and Migrate Root .lcm Subsystem to LCM_Inventory
Scope: LCM_AI, LCM_Inventory, Git_Repositories, LCM_Shared, Workspace Repositories
Author: rgbig
Date: 2026-10-13
Status: in_progress
Priority: High
```

---

## 1. Executive Summary

This proposal consolidates the Lifecycle Model (LCM) architecture across two core pillars:
1. **Canonical Rules in `LCM_AI`**: All 18 canonical governance rules and policies reside physically in `LCM_AI\.agents\rules`. Child repositories link to these rules without redundant lower-level sub-junctions where top-level junctions suffice.
2. **Subsystem Migration from Root `.lcm` to `LCM_Inventory`**: All modules (`LcmDaemon`), desktop runners (`LcmDesktopDaemon.ps1`, `Invoke-InteractiveDesktop.ps1`, `Register-LcmDesktopDaemon.ps1`), tools, and CLI command wrappers (`Cmd\*.cmd`) have been migrated into `LCM_Inventory`. Root `Git_Repositories` has been cleansed of all 283 tracked `.lcm` files.

---

## 2. Changes Made & Verification Evidence

### Step 1: Governance Rules & Top-Level Junctions
- **Audit**: Verified with `Test-LCMRuleHealth.ps1` that all 21 child repositories have zero physical rule duplicates and link cleanly to `LCM_AI\.agents\rules`.
- **Top-Level Invariant**: In root `Git_Repositories`, `D:\Git_Repositories\.agents` is the top-level junction to `LCM_AI\.agents`. No redundant sub-junctions exist.

### Step 2: BCompare Baseline Module Remediation (`BCompareBaseline.psm1`)
- **Higher-Up Junction Resolution**: Updated `Get-BCompareBaselineDescriptor` to detect when the parent `.agents` directory is a junction, resolving `RulesAuthorityPath`, `RulesAuthorityCommit`, and `RulesBaselineSource` (`authority-commit` or `target-history`) correctly.
- **Robust `.copilot` Baseline Re-Creation**: In `Export-BCompareBaseline`, internal tool junctions (`Rules`, `Atoms`, `Methods`) resolve to authority paths (`LCM_AI`) if local baseline sub-paths are absent, guaranteeing 100% parity between baseline and live panes and eliminating false orphan diffs.
- **Pester Verification**: All 6 tests in `LCM_Inventory/tests/BCompareBaseline.Tests.ps1` passed:
  ```
  Describing BCompare baseline
    [+] exports committed junction-backed rules from their local authority commit
    [+] uses the nearest target-history rules snapshot after a junction migration
    [+] leaves an authority rule absent from the baseline when it is not in the local commit
    [+] preserves historical file timestamps on exported baseline files
    [+] exports .copilot from authority baseline when target repository uses an external junction
    [+] exports rules when target repository uses a higher-up .agents junction
  Tests Passed: 6, Failed: 0
  ```

### Step 3: Subsystem Migration to `LCM_Inventory`
- **Modules**:
  - `LCM_Inventory/modules/LcmDaemon/` (`LcmDaemon.psm1`, `LcmDaemon.psd1`, `DaemonActionController.ps1`, `DaemonDto.ps1`, `DaemonEnvironment.ps1`).
  - `LCM_Inventory/modules/` (`LcmProgressAtom.psm1`, `LcmToolCatalog.psm1`, `ToolValidation.psm1`).
- **Tools**:
  - Migrated service runners (`LcmDesktopDaemon.ps1`, `Invoke-InteractiveDesktop.ps1`, `Register-LcmDesktopDaemon.ps1`, `Show-LcmDaemon.ps1`, etc.) into `LCM_Inventory/tools/`.
  - Replaced legacy `.lcm` references with `LCM_Inventory` paths.
- **Cmd Wrappers**:
  - Migrated 81 batch files to `LCM_Inventory/Cmd/`.
  - Updated all batch files to target `LCM_Inventory/tools/`.
- **Config & Catalog**:
  - Migrated `tool_catalog.json`, `tool_catalog_overrides.json`, and `tool_explorer_options.json` into `LCM_Inventory/config/`.

### Step 4: System Integration & Service Verification
- **Registry & Scheduled Task**:
  - Ran `Register-LcmDesktopDaemon.ps1 -Install`.
  - HKCU Run Key `LcmDesktopDaemon` configured to point to `D:\Git_Repositories\LCM_Inventory\tools\LcmDesktopDaemon.ps1`.
  - Scheduled task `LCM_DesktopDaemon_rgbig` configured for user logon with auto-restart.
- **Port 9876 Daemon Status**:
  - Terminated legacy daemon instance and started new instance from `LCM_Inventory`.
  - Verified REST endpoints:
    - `GET http://127.0.0.1:9876/status` -> 200 OK (ONLINE, Session 1, PID active).
    - `GET http://127.0.0.1:9876/session_state` -> 200 OK (OperatingMode: GOVERNED_IMPLEMENTATION).

### Step 5: Root `Git_Repositories` Cleansing
- Staged deletion of all 283 tracked `.lcm` files.
- Updated `D:\Git_Repositories\.gitignore` to explicitly ignore `/LCM_Inventory/` and `/.lcm`.
- Root repository is now a clean meta-container.
