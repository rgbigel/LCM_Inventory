---
Proposal-ID: CRP-2026-013
CR-ID: CR-2026-046
Scope: Workspace_AI
Version: v7.1.1
Affected-Repos: [Workspace_AI, Workspace_Inventory, .lcm, HaSSD06]
Status: Suggested
Date: 2026-08-30
Author: rgbig
Target Scope: Workspace-wide Maintenance, Deduplication & Platform Optimization
Affected Version Range: v7.1.1
Impacted Repositories: [Workspace_AI, Workspace_Inventory, .lcm, HaSSD06]
---

# CRP-2026-013: Workspace Artifact Deduplication, Archive Archiving & .lcd Junction Removal

## 1. Executive Summary & Intent
Perform an automated workspace-wide audit, hash-based content deduplication (CRC-64 / SHA-256), and safe archival migration to optimize workspace footprint, eliminate duplicate files (such as redundant `BootOpsHub.zip` instances in scratch directories and physical script duplicates in `.lcm\tools\links`), consolidate historical `data\baselines`, and remove the legacy `.lcd` backward-compatibility junction.

## 2. Invariant Rules & Archival Safety Standards
1. **Zero-Deletion Guarantee for Duplicate Data Artifacts**: Under no circumstances shall duplicate operational or data artifacts be permanently deleted. All redundant historical snapshots, legacy baselines, and duplicate scratch archives `MUST` be moved to dedicated structured `\archive` folders (e.g. `Workspace_Inventory/data/archives/`, `HaSSD06/data/archives/`).
2. **Canonical Version Preservation**: For duplicate files with identical hashes across directories, the authoritative and newest active version `MUST` remain in its primary location.
3. **Link Integrity in `.lcm\tools\links`**: Physical duplicate `.ps1` files in `.lcm\tools\links` will be archived, with execution routed dynamically via `tool_catalog.json` and `.lcm\Cmd\` trampolines.
4. **`.lcd` Cleanup**: The temporary backward-compatibility junction `D:\Git_Repositories\.lcd` will be cleanly removed, finalizing `.lcm` as the sole platform engine path.

## 3. Deduplication Architecture & Workflows
1. **`Invoke-WorkspaceDeduplication.ps1`**: A high-performance PowerShell tool supporting `-AuditOnly`, `-Apply`, `-Algorithm <SHA256|CRC64>`, `-ArchiveRoot <path>`.
2. **Target Scope of Clean-Up**:
   - `Workspace_Inventory\scratch\BC_Review\*` (Historical BC review snapshots containing duplicate `BootOpsHub.zip`, `CommandHub.zip`, etc.) $\to$ Moved to `Workspace_Inventory\data\archives\BC_Review_Snapshots\`.
   - `.lcm\tools\links\*.ps1` (Physical copies of child tools) $\to$ Archived to `.lcm\archive\tools_links_backup\`.
   - `Workspace_Inventory\data\baselines\BASELINE-v4.*.json` $\to$ Consolidated into `Workspace_Inventory\data\archives\baselines\`.
   - `HaSSD06\scratch\srat*` $\to$ Archived to `HaSSD06\data\archives\srat_archive\`.
   - `D:\Git_Repositories\.lcd` junction $\to$ Removed via `cmd /c rmdir D:\Git_Repositories\.lcd`.
