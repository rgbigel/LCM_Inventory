# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-16 14:49:30
Global Baseline Version: **v4.2.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **34** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v4.2.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **5** | Actively governed under LCM |
| **Elevation Required Repositories** | **11** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **12** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **10** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`BackgroundModifier`** | Git | `main` | `882b160` | clean | **governed** | - | v4.2.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `5ca3ba3` | clean | **governed** | - | v4.2.0 | **Admin** | lcm-governed |
| **`BootEntryManager`** | Git | `HEAD` | `` | modified (5 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`BootOpsHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`CommandHub`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DeviceInventory`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DiskAssignmentStatus`** | Git | `DocPhase` | `f6dcc42` | modified (46 files) | **not-lcm** | - | - | User | standard-git |
| **`DiskAssignmentStatus_AC`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`DiskAssignmentStatus_S1`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`EnvironmentTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`FileUtilities`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`GetRecoveryVolume`** | Git | `HEAD` | `` | modified (3 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`GitTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`InstallFonts`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `HEAD` | `` | modified (8 files) | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `HEAD` | `` | modified (5 files) | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `HEAD` | `` | modified (11 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `HEAD` | `` | modified (19 files) | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `HEAD` | `` | modified (16 files) | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `HEAD` | `` | modified (3 files) | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `HEAD` | `` | modified (3 files) | **not-lcm** | - | - | User | standard-git |
| **`SystemConfiguration`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`TimeStamper`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `main` | `852d693` | clean | **governed** | - | v4.2.0 | **Admin** | lcm-governed |
| **`Workspace_AC`** | Git | `main` | `eb35191` | clean | **not-lcm** | - | - | User | legacy-retired |
| **`Workspace_AI`** | Git | `main` | `4704278` | clean | **governed** | v4.2.0 | v4.2.0 | User | active-design-workshop |
| **`Workspace_GC`** | Git | `main` | `5576337` | clean | **not-lcm** | - | - | User | legacy-retired |
| **`Workspace_Inventory`** | Git | `main` | `d91fcc1` | clean | **governed** | v4.2.0 | v4.2.0 | **Admin** | configuration-management |

