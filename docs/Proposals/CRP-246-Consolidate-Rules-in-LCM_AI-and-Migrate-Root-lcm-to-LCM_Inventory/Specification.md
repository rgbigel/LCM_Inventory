# Change Request Proposal: CRP-246

```yaml
CRP-ID: CRP-246
Title: Consolidate Canonical Rules in LCM_AI and Migrate Root .lcm Subsystem to LCM_Inventory
Scope: LCM_AI, LCM_Inventory, Git_Repositories, LCM_Shared, Workspace Repositories
Baseline-Version: 10.2.0
Author: rgbig
Date: 2026-10-13
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent

Over successive iterations of the Lifecycle Model (LCM) architecture, two structural anomalies have emerged that introduce friction, review noise, and maintenance complexity:

1. **Scattered Governance Rules & Redundant Junctions**:
   Governance rules and policy artifacts have historically existed in multiple forms across repositories. Although `LCM_AI\.agents\rules` is the primary hub, legacy sub-junctions (such as per-repo `.agents\rules` junctions instead of leveraging higher-up `.agents` junctions where feasible, or redundant `.agents\rules` links) complicate baseline extraction in Beyond Compare and create drift risk. The operator directive mandates that **ALL LCM rules must reside physically and authoritatively in a single folder in `LCM_AI` (`LCM_AI\.agents\rules`)**. Child repositories and tools must access these rules via top-level linkage/junctions without introducing lower-level redundant junctions where higher-up junctions can do the job.

2. **Physical Code Housed in Root `.lcm` Subsystem**:
   Physical application code, PowerShell modules (`LcmDaemon`, `DaemonActionController.ps1`), desktop runner scripts (`LcmDesktopDaemon.ps1`, `Invoke-InteractiveDesktop.ps1`, `Register-LcmDesktopDaemon.ps1`), command wrappers (`LCM_Inventory\Cmd\`), and internal tools currently reside in `D:\Git_Repositories\LCM_Inventory\`. This causes the root multi-repo container (`Git_Repositories`) to track 280+ physical files and act as an active software repository requiring its own review-commit cycle. All LCM runtime code, daemon services, macros, and operational tools belong authoritatively in **`LCM_Inventory`**. Where sibling repositories or tools require access, clean linkage/interfaces must be established rather than code duplication.

---

## 2. Scope of Work

### Phase A: Rules Authority Consolidation & High-Level Junction Topology
- **Single Authoritative Rule Hub**: Confirm and enforce `D:\Git_Repositories\LCM_AI\.agents\rules` as the sole physical repository for all LCM rules, governance policies, and display standards.
- **Audit & Clean Local Variants**: Identify and eliminate any physical rule duplicates or outdated local variants in any child repository.
- **Top-Level Junction Invariant**:
  - In root `Git_Repositories`, `D:\Git_Repositories\.agents` is the top-level NTFS junction to `LCM_AI\.agents`. No redundant child junctions (such as `.agents\rules`) should exist within `Git_Repositories`.
  - In child repositories where `.agents` is not housing repo-specific data, simplify linkage so that higher-up junctions or clean top-level `.agents` junctions target `LCM_AI\.agents`.
- **Baseline Extraction Parity**:
  - Update `BCompareBaseline.psm1` so that `Get-BCompareBaselineDescriptor` and `Export-BCompareBaseline` recognize higher-up `.agents` junctions (e.g., when `.agents` is a junction, its child `.agents\rules` is correctly resolved and exported from `LCM_AI` baseline).
  - Ensure `.copilot` baseline extraction accurately mirrors the live folder topology without leaving orphan difference entries in Beyond Compare.

### Phase B: Subsystem Relocation from Root `.lcm` to `LCM_Inventory`
- **Module Migration**:
  - Move `LCM_Inventory\modules\LcmDaemon\` (`LcmDaemon.psm1`, `LcmDaemon.psd1`, `DaemonActionController.ps1`, `DaemonDto.ps1`, `DaemonEnvironment.ps1`) into `LCM_Inventory\modules\LcmDaemon\`.
  - Move `LCM_Inventory\modules\LcmProgressAtom.psm1`, `LcmToolCatalog.psm1`, `ToolValidation.psm1` into `LCM_Inventory\modules\`.
- **Service & Desktop Dispatcher Migration**:
  - Move `LCM_Inventory\tools\LcmDesktopDaemon.ps1`, `Invoke-InteractiveDesktop.ps1`, and `Register-LcmDesktopDaemon.ps1` into `LCM_Inventory\tools\` (or dedicated `LCM_Inventory\tools\daemon\`).
  - Move daemon logging and scratch directories into `LCM_Inventory\logs\` and `LCM_Inventory\scratch\`.
- **CLI & Command Wrappers Migration**:
  - Move `LCM_Inventory\Cmd\` batch files (`ShowCM.cmd`, `ShowTools.cmd`, etc.) to `LCM_Inventory\cmd\`.
  - Update user environment `PATH` configuration or provide unified wrappers in `d:\OneDrive\cmd\` or `LCM_Inventory\cmd\`.
- **System & Registry Integration**:
  - Update `Register-LcmDesktopDaemon.ps1` and `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` to point to the new daemon path in `LCM_Inventory`.
  - Restart the daemon under Session 1 with zero service interruption.
- **Root Git Cleanup**:
  - Remove `LCM_Inventory/` from Git tracking in root `Git_Repositories`.
  - Reduce root `Git_Repositories` to a pure, lightweight governance container (~12 tracked files: `AGENTS.md`, `GEMINI.md`, `.gitignore`, `.gitattributes`, etc.).

### Phase C: Cross-Repository Linkage (Zero Code Duplication)
- If sibling repositories (e.g. `LCM_Shared`) require access to LCM inventory modules or tools, establish deterministic references or PowerShell module path configuration (`$env:PSModulePath`) rather than duplicating files.

---

## 3. Impact Analysis & Risk Management

| Risk | Impact | Mitigation |
|:---|:---|:---|
| Daemon Service Disruption | Medium | Deploy new daemon in `LCM_Inventory` and test port 9876 `/status` before re-registering startup and terminating old process. |
| Broken CLI Paths (`ShowCM.cmd`) | Low | Update environment `PATH` and verify batch commands resolve correctly. |
| BC Review Baseline Glitch | Low | Update `BCompareBaseline.psm1` to handle higher-up `.agents` junctions and validate with Pester tests before cutover. |
| Git History Preservation | Low | Use standard Git file staging or migration tracking so history is maintained where appropriate. |

---

## 4. Verification & Acceptance Criteria
1. `LCM_AI\.agents\rules` contains all canonical governance rules (18 files).
2. Zero physical duplicate rule files exist in any child repository.
3. No redundant sub-junctions exist where a higher-up junction already provides access.
4. `D:\Git_Repositories\.lcm` contains zero tracked Git files; root repository is clean.
5. All Daemon modules, classes, and service scripts run from `LCM_Inventory`.
6. Port 9876 Daemon is healthy and actively serving requests from `LCM_Inventory`.
7. Beyond Compare Review (`BCR`) on all repositories accurately exports rules and `.copilot` baselines without ghost orphan differences.


---

## 5. Reference: Retired .lcm to Current Paths

The authoritative record of where the retired root `.lcm` folder went is [reference/lcm-to-new-paths.json](reference/lcm-to-new-paths.json) (longest `from` wins; paths relative to the workspace root). It documents the restructuring and is the input of `LCM_Inventory/tools/Invoke-LcmPathMigration.ps1`. The working copy `LCM_Inventory/config/lcm-path-map.json` stays until the LCM_Root cutover is complete; this copy is permanent.
