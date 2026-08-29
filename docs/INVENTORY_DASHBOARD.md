# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-29 22:44:55
Global Baseline Version: **v7.0.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **28** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v7.0.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **12** | Actively governed under LCM |
| **Elevation Required Repositories** | **10** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **8** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **3** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.git`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.lcd`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Git | `main` | `775beaf` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `3b3dca0` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `ff72fc9` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `355bd2e` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | lcm-governed |
| **`HaSSD06`** | Git | `main` | `e40bb4c` | modified (17 files) | **governed** | v7.0.0 | v7.0.0 | User | subsystem |
| **`HaSSD06_Inventory`** | Git | `main` | `5972d7b` | modified (17 files) | **governed** | v7.0.0 | v7.0.0 | User | subsystem-inventory |
| **`Installation_LCD`** | Git | `main` | `3dac106` | modified (17 files) | **governed** | v7.0.0 | v7.0.0 | User | lcm-governed |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `de88fc5` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `main` | `302526b` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `3e3c2f9` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | User | lcm-governed |
| **`SystemConfiguration`** | Git | `main` | `fe096ea` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | lcm-governed |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`tools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`VolumeInventory`** | Git | `main` | `8058b8e` | modified (1 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `c19f2e0` | modified (22 files) | **governed** | v7.0.0 | v7.0.0 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `dd510a4` | modified (9 files) | **governed** | v7.0.0 | v7.0.0 | **Admin** | configuration-management |

