# Implementation Plan: CRP-246

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

## 1. Execution Steps & Phased Rollout

### Step 1: Governance Rules & Junctions Optimization
- [ ] Verify `LCM_AI\.agents\rules` contains all 18 canonical rule files.
- [ ] Scan all child repositories to confirm zero physical rule files or outdated local copies exist.
- [ ] Check junction architecture:
  - Root `Git_Repositories\.agents` -> `LCM_AI\.agents` (higher-up junction).
  - Confirm no redundant child junction `Git_Repositories\.agents\rules` is present.
  - Sibling repositories maintain clean linkage to `LCM_AI\.agents`.

### Step 2: Fix BCompare Baseline Module (`BCompareBaseline.psm1`)
- [ ] In `Get-BCompareBaselineDescriptor`, support higher-up junctions:
  - If `$RepositoryPath\.agents` is a junction targeting `LCM_AI\.agents`, resolve `RulesBaselineRepositoryPath = LCM_AI` and `RulesBaselineCommit` from `LCM_AI` HEAD commit.
- [ ] In `Export-BCompareBaseline`:
  - When `.agents` is exported from the authority, recreate the proper baseline directory structure.
  - Ensure baseline `.copilot` correctly links or copies `Rules`, `Atoms`, and `Methods` so Beyond Compare does not show false differences against Live.
- [ ] Validate baseline generation with tests.

### Step 3: Migrate Subsystem Code from `.lcm` to `LCM_Inventory`
- [ ] **Modules Migration**:
  - Copy/move `D:\Git_Repositories\LCM_Inventory\modules\LcmDaemon\` into `D:\Git_Repositories\LCM_Inventory\modules\LcmDaemon\`.
  - Copy/move `LcmProgressAtom.psm1`, `LcmToolCatalog.psm1`, and `ToolValidation.psm1` into `D:\Git_Repositories\LCM_Inventory\modules\`.
- [ ] **Tools & Dispatchers**:
  - Copy/move `LcmDesktopDaemon.ps1`, `Invoke-InteractiveDesktop.ps1`, and `Register-LcmDesktopDaemon.ps1` into `D:\Git_Repositories\LCM_Inventory\tools\`.
  - Update internal paths in `LcmDesktopDaemon.ps1` and `Invoke-InteractiveDesktop.ps1` to resolve modules and logs from `LCM_Inventory`.
- [ ] **CLI Wrappers**:
  - Copy/move batch wrappers from `D:\Git_Repositories\LCM_Inventory\Cmd\` to `D:\Git_Repositories\LCM_Inventory\cmd\`.
- [ ] **Cross-Repository Linkage**:
  - For `LCM_Shared` or other repos needing LCM modules, configure module paths or deterministic linkage rather than copying files.

### Step 4: System Integration & Service Migration
- [ ] Update `Register-LcmDesktopDaemon.ps1` to register `LCM_Inventory\tools\LcmDesktopDaemon.ps1` in Windows Run key (`HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`).
- [ ] Re-register the startup entry.
- [ ] Restart daemon service on Port 9876 from `LCM_Inventory`.
- [ ] Verify REST API endpoints (`/status`, `/session_state`) return healthy 200 responses.

### Step 5: Clean Root `Git_Repositories`
- [ ] Remove `LCM_Inventory/` tracking from Git in `D:\Git_Repositories`.
- [ ] Retain local logs/scratch in `.gitignore` or clean up as needed.
- [ ] Verify `git status` on root `Git_Repositories`.

### Step 6: Visual Review Gate (`BCR`)
- [ ] Launch Beyond Compare Review on impacted repositories (`LCM_Inventory`, `Git_Repositories`).
- [ ] Verify baseline accurately reflects changes without false orphan diffs.
- [ ] Await operator review disposition.
