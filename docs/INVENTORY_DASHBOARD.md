# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-09-05 22:43:06
Global Baseline Version: **v7.1.1** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **31** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v7.1.1) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **14** | Actively governed under LCM |
| **Elevation Required Repositories** | **9** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **9** | Un-onboarded Git repos |
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
| **`.lcm`** | Non-Git | `-` | `-` | clean | **governed** | v7.1.1 | v7.1.1 | **Admin** | platform-engine |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Git | `main` | `9e1a3d2` | clean | **governed** | v7.1.1 | v7.1.1 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `5b41675` | clean | **governed** | v7.1.1 | v7.1.1 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `d0dc246` | clean | **governed** | v7.1.1 | v7.1.1 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `7278e27` | clean | **governed** | v7.1.1 | v7.1.1 | **Admin** | lcm-governed |
| **`docs`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Git | `main` | `7b8df0d` | modified (7 files) | **governed** | v7.1.1 | v7.1.1 | User | subsystem |
| **`HaSSD06_Inventory`** | Git | `main` | `8f058e9` | modified (9 files) | **governed** | v7.1.1 | v7.1.1 | User | subsystem-inventory |
| **`Installation_LCD`** | Git | `main` | `e7981aa` | modified (8 files) | **governed** | v7.1.1 | v7.1.1 | User | lcm-governed |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`LCM_Backup`** | Git | `HEAD` | `` | modified (6 files) | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `de88fc5` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `main` | `302526b` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `fd8ac80` | clean | **governed** | v7.1.1 | v7.1.1 | User | lcm-governed |
| **`SystemConfiguration`** | Git | `main` | `7d493ee` | modified (5 files) | **governed** | v7.1.1 | v7.1.1 | **Admin** | lcm-governed |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`tools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`VolumeInventory`** | Git | `main` | `0ea46d1` | clean | **governed** | v7.1.1 | v7.1.1 | **Admin** | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `f2b141e` | modified (1 files) | **governed** | v7.1.1 | v7.1.1 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `2ff3206` | modified (5 files) | **governed** | v7.1.1 | v7.1.1 | **Admin** | configuration-management |
| **`Workspace_Supervision`** | Git | `main` | `12c1b43` | modified (6 files) | **governed** | v7.1.1 | v7.1.1 | User | subsystem |

