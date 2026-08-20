# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-20 22:27:58
Global Baseline Version: **v5.0.1** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **33** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v5.0.1) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **3** | Actively governed under LCM |
| **Elevation Required Repositories** | **8** | Repositories requiring Administrator privileges |
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
| **`AuthorizeMasterUser`** | Git | `main` | `86f35ed` | clean | **governed** | v5.0.1 | v5.0.1 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `de855b0` | modified (3 files) | **outdated** | v5.0.0 | v4.3.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `10351be` | modified (1 files) | **outdated** | v5.0.0 | v4.2.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `ed63ce3` | modified (1 files) | **outdated** | v5.0.0 | v4.2.0 | User | lcm-governed |
| **`BootOpsHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`CommandHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DeviceInventory`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DiskAssignmentStatus`** | Git | `DocPhase` | `f6dcc42` | modified (47 files) | **not-lcm** | - | - | User | standard-git |
| **`DiskAssignmentStatus_S1`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`EnvironmentTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`FileUtilities`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`GetRecoveryVolume`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`GitTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`InstallFonts`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `HEAD` | `` | modified (8 files) | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `HEAD` | `` | modified (5 files) | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `HEAD` | `` | modified (11 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `HEAD` | `` | modified (19 files) | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `HEAD` | `` | modified (16 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `HEAD` | `` | modified (3 files) | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `db62117` | modified (1 files) | **outdated** | v5.0.0 | v4.2.0 | User | lcm-governed |
| **`SystemConfiguration`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`TimeStamper`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `main` | `c5f5d41` | modified (5 files) | **outdated** | v5.0.0 | v4.2.0 | User | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `91b5c90` | clean | **governed** | v5.0.1 | v5.0.1 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `4f4c398` | clean | **governed** | v5.0.1 | v5.0.1 | **Admin** | configuration-management |

