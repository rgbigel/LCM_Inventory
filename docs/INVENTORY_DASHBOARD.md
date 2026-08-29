# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-29 18:02:38
Global Baseline Version: **v6.1.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **26** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v6.1.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **11** | Actively governed under LCM |
| **Elevation Required Repositories** | **9** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **8** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **2** | Non-Git folders (git.ignoredRepositories) |
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
| **`AuthorizeMasterUser`** | Git | `main` | `c32b9e0` | modified (2 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `54b16dc` | modified (1 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `4c7ac2d` | modified (1 files) | **governed** | v6.1.0 | v6.1.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `3aeaa87` | modified (1 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | lcm-governed |
| **`HaSSD06`** | Git | `main` | `4ff1219` | modified (21 files) | **governed** | v6.1.0 | v6.1.0 | User | subsystem |
| **`HaSSD06_Inventory`** | Git | `main` | `7b14cbf` | modified (15 files) | **governed** | v6.1.0 | v6.1.0 | User | subsystem-inventory |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `de88fc5` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `main` | `302526b` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `3793a14` | modified (1 files) | **governed** | v6.1.0 | v6.1.0 | User | lcm-governed |
| **`SystemConfiguration`** | Git | `main` | `4ebdb9d` | modified (11 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | lcm-governed |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`tools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`VolumeInventory`** | Git | `main` | `865baf3` | modified (1 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `ee11ef6` | modified (18 files) | **governed** | v6.1.0 | v6.1.0 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `8fdde54` | modified (2 files) | **governed** | v6.1.0 | v6.1.0 | **Admin** | configuration-management |

