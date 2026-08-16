# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-16 13:26:53
Global Baseline Version: **v4.1.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **34** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v4.1.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **5** | Actively governed under LCM |
| **Standard Git Repositories** | **12** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **10** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | parent-infra |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | parent-infra |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | parent-infra |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | parent-infra |
| **`AuthorizeMasterUser`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`BackgroundModifier`** | Git | `main` | `61dabef` | modified (1 files) | **governed** | - | v4.1.0 | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `532840f` | clean | **governed** | - | v4.1.0 | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `-` | modified (5 files) | **not-lcm** | - | - | standard-git |
| **`BootOpsHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`CommandHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`DeviceInventory`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`DiskAssignmentStatus`** | Git | `DocPhase` | `f6dcc42` | modified (46 files) | **not-lcm** | - | - | standard-git |
| **`DiskAssignmentStatus_AC`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`DiskAssignmentStatus_S1`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`EnvironmentTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`FileUtilities`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`GetRecoveryVolume`** | Git | `main` | `-` | modified (3 files) | **not-lcm** | - | - | standard-git |
| **`GitTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`InstallFonts`** | Git | `main` | `-` | modified (4 files) | **not-lcm** | - | - | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `-` | modified (8 files) | **not-lcm** | - | - | standard-git |
| **`MSG file conversion`** | Git | `main` | `-` | modified (5 files) | **not-lcm** | - | - | standard-git |
| **`NextBootTray`** | Git | `main` | `-` | modified (11 files) | **not-lcm** | - | - | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `-` | modified (19 files) | **not-lcm** | - | - | standard-git |
| **`PowerBGInfo`** | Git | `main` | `-` | modified (16 files) | **not-lcm** | - | - | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `-` | modified (3 files) | **not-lcm** | - | - | standard-git |
| **`SharedModules`** | Git | `main` | `-` | modified (3 files) | **not-lcm** | - | - | standard-git |
| **`SystemConfiguration`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | non-git |
| **`TimeStamper`** | Git | `main` | `-` | modified (4 files) | **not-lcm** | - | - | standard-git |
| **`VolumeInventory`** | Git | `main` | `435c4d7` | clean | **governed** | - | v4.1.0 | lcm-governed |
| **`Workspace_AC`** | Git | `main` | `eb35191` | clean | **not-lcm** | - | - | legacy-retired |
| **`Workspace_AI`** | Git | `main` | `87b59ae` | clean | **governed** | v4.1.0 | v4.1.0 | active-design-workshop |
| **`Workspace_GC`** | Git | `main` | `5576337` | clean | **not-lcm** | - | - | legacy-retired |
| **`Workspace_Inventory`** | Git | `main` | `fcb5270` | clean | **governed** | v4.1.0 | v4.1.0 | configuration-management |

