# Implementation Plan - Proposal #35 (CRP-2026-013): Workspace Artifact Deduplication, Archive Consolidation & .lcd Junction Removal

## User Review Required
> [!IMPORTANT]
> **Zero-Deletion Archival Invariant**: Redundant duplicate data artifacts (such as older baseline JSON snapshots, duplicate `BootOpsHub.zip` instances in scratch review staging, and physical scripts in `.lcm/tools/links`) will **strictly be moved to dedicated structured `\archive` folders** and will **never be deleted**.

> [!NOTE]
> **`.lcd` Removal**: The temporary backward-compatibility junction `D:\Git_Repositories\.lcd` created during the `.lcm` migration will be removed, establishing `.lcm` as the sole canonical platform root.

---

## Proposed Changes

### Configuration Management & Deduplication Engine (`Workspace_Inventory`)

#### [NEW] [Invoke-WorkspaceDeduplication.ps1](file:///d:/Git_Repositories/Workspace_Inventory/tools/Invoke-WorkspaceDeduplication.ps1)
* High-performance content-hashing deduplication runner supporting SHA-256 and CRC-64 verification.
* Safely moves identical older/redundant duplicates from staging and cache directories into organized `data/archives/` subfolders.
* Supports `-AuditOnly` (dry run) and `-Apply` execution modes.

#### [MODIFY] [Show-WorkspaceInventoryApp.ps1](file:///d:/Git_Repositories/Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1)
* Remove legacy fallback checks to `.lcd`.

---

### Platform Engine (`.lcm`)

#### [MODIFY] [.lcm/tools/links/](file:///d:/Git_Repositories/.lcm/tools/links)
* Move the 66 physical duplicate scripts currently stored in `.lcm\tools\links` into `.lcm\archive\tools_links_backup\`.
* Ensure tool discovery and execution are routed dynamically through `tool_catalog.json` and `.lcm\Cmd\` trampolines.

#### [DELETE] [D:\Git_Repositories\.lcd](file:///d:/Git_Repositories/.lcd)
* Remove the temporary NTFS junction `D:\Git_Repositories\.lcd <<===>> D:\Git_Repositories\.lcm`.

---

### Subsystems & Staging Clean-up (`HaSSD06` & `Workspace_Inventory`)

#### [ARCHIVE] [Workspace_Inventory/scratch/BC_Review/*](file:///d:/Git_Repositories/Workspace_Inventory/scratch/BC_Review)
* Move the 3 historical staging snapshot directories (`CRP-2026-005_*`, `CRP-2026-006_*`, `CRP-2026-008_*`) containing redundant `BootOpsHub.zip` and review JSONs into `Workspace_Inventory/data/archives/BC_Review_Snapshots/`.

#### [ARCHIVE] [Workspace_Inventory/data/baselines/*](file:///d:/Git_Repositories/Workspace_Inventory/data/baselines)
* Move legacy baseline snapshots (`BASELINE-v4.1.0-20260815.json`, `BASELINE-v4.2.0-20260816.json`, `baseline-v4.1.0.json`) into `Workspace_Inventory/data/archives/baselines/`, preserving the newest active baseline `BASELINE-v4.3.0.json`.

#### [ARCHIVE] [HaSSD06/scratch/srat*](file:///d:/Git_Repositories/HaSSD06/scratch)
* Move `srat.zip`, `srat_release.zip`, and extracted directories into `HaSSD06/data/archives/srat_archive/`.

---

## Verification Plan

### Automated Tests
1. **Deduplication Audit Dry Run**:
   ```powershell
   pwsh -File Workspace_Inventory/tools/Invoke-WorkspaceDeduplication.ps1 -AuditOnly
   ```
2. **Deduplication Execution**:
   ```powershell
   pwsh -File Workspace_Inventory/tools/Invoke-WorkspaceDeduplication.ps1 -Apply
   ```
3. **Workspace Readiness & Health Check**:
   ```powershell
   pwsh -File Workspace_Inventory/tools/Invoke-WorkspaceAudit.ps1
   pwsh -File .lcm/tools/internal/Test-LCMRuleHealth.ps1
   ```
4. **Daemon & Path Validation**:
   ```powershell
   curl.exe -s http://127.0.0.1:9876/ping
   ```

### Manual Verification
* Verify that `BootOpsHub.zip` exists in its single authoritative location in `Workspace_Inventory/data/archives/` and no longer duplicates in active working trees.
* Confirm that `.lcd` is gone while `.lcm` tools and commands continue functioning flawlessly.
