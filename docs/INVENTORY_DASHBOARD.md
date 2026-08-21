# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-21 16:43:46
Global Baseline Version: **v5.0.2** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **33** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v5.0.2) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **2** | Actively governed under LCM |
| **Elevation Required Repositories** | **10** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **10** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **10** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.git`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Git | `main` | `a707d62` | clean | **outdated** | v5.0.2 | v5.0.1 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `25f14c9` | clean | **outdated** | v5.0.2 | v4.3.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `a672f75` | clean | **outdated** | v5.0.2 | v4.2.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `ba0c1fd` | clean | **outdated** | v5.0.2 | v4.2.0 | **Admin** | lcm-governed |
| **`BootOpsHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`CommandHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DeviceInventory`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DiskAssignmentStatus`** | Git | `DocPhase` | `4b301e9` | clean | **not-lcm** | - | - | User | standard-git |
| **`DiskAssignmentStatus_S1`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`EnvironmentTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`FileUtilities`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`GetRecoveryVolume`** | Git | `main` | `8310049` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`GitTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `de88fc5` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `main` | `302526b` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `fc2c80f` | clean | **outdated** | v5.0.2 | v4.2.0 | User | lcm-governed |
| **`SystemConfiguration`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `main` | `d1aaa68` | clean | **outdated** | v5.0.2 | v4.2.0 | **Admin** | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `52e1ee7` | modified (4 files) | **governed** | v5.0.2 | v5.0.2 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `f793b04` | clean | **governed** | v5.0.2 | v5.0.2 | **Admin** | configuration-management |

