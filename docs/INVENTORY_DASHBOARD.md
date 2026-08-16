# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-16 17:34:15
Global Baseline Version: **v4.3.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **34** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v4.3.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **2** | Actively governed under LCM |
| **Elevation Required Repositories** | **7** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **10** | Un-onboarded Git repos |
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
| **`BackgroundModifier`** | Git | `main` | `64bae74` | clean | **outdated** | - | v4.2.0 | User | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `7c175fe` | clean | **outdated** | - | v4.2.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `1c42769` | clean | **outdated** | - | v4.2.0 | User | lcm-governed |
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
| **`SharedModules`** | Git | `main` | `1e030fb` | clean | **outdated** | - | v4.2.0 | User | lcm-governed |
| **`SystemConfiguration`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`TimeStamper`** | Git | `HEAD` | `` | modified (4 files) | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `main` | `9c10deb` | clean | **outdated** | - | v4.2.0 | User | lcm-governed |
| **`Workspace_AC`** | Git | `main` | `eb35191` | clean | **not-lcm** | - | - | User | legacy-retired |
| **`Workspace_AI`** | Git | `main` | `1f61285` | clean | **governed** | v4.3.0 | v4.3.0 | User | active-design-workshop |
| **`Workspace_GC`** | Git | `main` | `5576337` | clean | **not-lcm** | - | - | User | legacy-retired |
| **`Workspace_Inventory`** | Git | `main` | `bfad22a` | clean | **governed** | v4.3.0 | v4.3.0 | **Admin** | configuration-management |

