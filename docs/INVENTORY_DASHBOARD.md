# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md  
Purpose: Real-time inventory and drift status dashboard of all repositories under D:\Git_Repositories.  
Path: docs/INVENTORY_DASHBOARD.md  
Generated: 2026-11-11 15:52:29  
Global Baseline Version: **v10.2.3** (Source: LCM_AI)  

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **31** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | LCM_AI (v10.2.3) |
| **CM Repository** | **1** | LCM_Inventory |
| **LCM Governed / Candidates** | **10** | Actively governed under LCM |
| **Elevation Required Repositories** | **8** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **12** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **4** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.git`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.githooks`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Git | `NewStructure` | `04c3b42` | clean | **governed** | v10.2.3 | v10.2.3 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `NewStructure` | `014258f` | clean | **governed** | v10.2.3 | v10.2.3 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `NewStructure` | `8ae2d85` | clean | **governed** | v10.2.3 | v10.2.3 | User | lcm-governed |
| **`BootEntryManager`** | Git | `NewStructure` | `142d0a4` | clean | **governed** | v10.2.3 | v10.2.3 | **Admin** | lcm-governed |
| **`docs`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Git | `NewStructure` | `b7819d7` | clean | **not-lcm** | - | - | User | standard-git |
| **`HaSSD06_Inventory`** | Git | `NewStructure` | `75e954b` | clean | **not-lcm** | - | - | User | standard-git |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`LCM_AI`** | Git | `main` | `ec53079` | modified (4 files) | **governed** | v10.2.3 | v10.2.3 | User | active-design-workshop |
| **`LCM_Inventory`** | Git | `main` | `c055dda` | modified (88 files) | **governed** | v10.2.3 | v10.2.3 | **Admin** | configuration-management |
| **`LCM_Shared`** | Git | `NewStructure` | `8e43bc7` | clean | **governed** | v10.2.3 | v10.2.3 | User | lcm-governed |
| **`LCM_Supervision`** | Git | `NewStructure` | `0c8688f` | clean | **governed** | v10.2.3 | v10.2.3 | User | lcm-governed |
| **`LCM_SystemConfiguration`** | Git | `HEAD` | `` | modified (11 files) | **governed** | v10.2.3 | v10.2.3 | **Admin** | lcm-governed |
| **`LCM_Tools`** | Git | `main` | `da6473a` | modified (178 files) | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `f0986bc` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OneDriveMaintenance`** | Git | `main` | `981a285` | modified (1 files) | **not-lcm** | - | - | User | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`RollingCalendar`** | Git | `NewStructure` | `5b1bec1` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`scratch`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `NewStructure` | `377071e` | clean | **governed** | v10.2.3 | v10.2.3 | **Admin** | lcm-governed |

