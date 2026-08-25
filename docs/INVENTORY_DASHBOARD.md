# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-08-25 18:39:32
Global Baseline Version: **v6.0.0** (Source: Workspace_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **30** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | Workspace_AI (v6.0.0) |
| **CM Repository** | **1** | Workspace_Inventory |
| **LCM Governed / Candidates** | **2** | Actively governed under LCM |
| **Elevation Required Repositories** | **9** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **8** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **6** | Non-Git folders (git.ignoredRepositories) |
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
| **`AuthorizeMasterUser`** | Git | `main` | `a707d62` | modified (1 files) | **outdated** | v5.1.0 | v5.0.1 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `main` | `25f14c9` | modified (2 files) | **outdated** | v5.1.0 | v4.3.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `main` | `a672f75` | modified (1 files) | **outdated** | v5.1.0 | v4.2.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `main` | `ba0c1fd` | modified (1 files) | **outdated** | v5.1.0 | v4.2.0 | **Admin** | lcm-governed |
| **`docs`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`EnvironmentTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`FileUtilities`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`GitTools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Git | `main` | `521fb3b` | clean | **outdated** | v5.1.0 | v5.1.0 | User | subsystem |
| **`HaSSD06_Inventory`** | Git | `main` | `007e2e3` | clean | **outdated** | v5.1.0 | v5.1.0 | User | subsystem-inventory |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `de88fc5` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`PowerBGInfo`** | Git | `main` | `302526b` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`SharedModules`** | Git | `main` | `3793a14` | clean | **outdated** | v5.1.0 | v4.2.0 | User | lcm-governed |
| **`SystemConfiguration`** | Git | `main` | `c5b3486` | modified (175 files) | **outdated** | v5.1.0 | v4.2.0 | **Admin** | lcm-governed |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`tools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | **Admin** | non-git |
| **`VolumeInventory`** | Git | `main` | `d1aaa68` | modified (3 files) | **outdated** | v5.1.0 | v4.2.0 | **Admin** | lcm-governed |
| **`Workspace_AI`** | Git | `main` | `7b34bf6` | clean | **governed** | v6.0.0 | v6.0.0 | User | active-design-workshop |
| **`Workspace_Inventory`** | Git | `main` | `38c95a5` | modified (1 files) | **governed** | v6.0.0 | v6.0.0 | **Admin** | configuration-management |

