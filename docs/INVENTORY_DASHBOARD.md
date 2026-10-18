# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-10-18 17:47:34
Global Baseline Version: **v10.0.0** (Source: LCM_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **28** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | LCM_AI (v10.0.0) |
| **CM Repository** | **1** | LCM_Inventory |
| **LCM Governed / Candidates** | **9** | Actively governed under LCM |
| **Elevation Required Repositories** | **7** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **10** | Un-onboarded Git repos |
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
| **`AuthorizeMasterUser`** | Git | `NewStructure` | `c7e5968` | clean | **governed** | v10.0.0 | v10.0.0 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `NewStructure` | `f2b8895` | clean | **governed** | v10.0.0 | v10.0.0 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `NewStructure` | `a3abdb7` | clean | **governed** | v10.0.0 | v10.0.0 | User | lcm-governed |
| **`BootEntryManager`** | Git | `NewStructure` | `e3b2eb6` | clean | **governed** | v10.0.0 | v10.0.0 | **Admin** | lcm-governed |
| **`docs`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Git | `NewStructure` | `a41fe3a` | clean | **not-lcm** | - | - | User | standard-git |
| **`HaSSD06_Inventory`** | Git | `NewStructure` | `b70af18` | clean | **not-lcm** | - | - | User | standard-git |
| **`InstallFonts`** | Git | `main` | `37a275a` | clean | **not-lcm** | - | - | User | standard-git |
| **`LCM_AI`** | Git | `main` | `e315a27` | modified (2 files) | **governed** | v10.0.0 | v10.0.0 | User | active-design-workshop |
| **`LCM_Inventory`** | Git | `main` | `24adeea` | modified (16 files) | **governed** | v10.0.0 | v10.0.0 | **Admin** | configuration-management |
| **`LCM_Shared`** | Git | `NewStructure` | `0707065` | clean | **governed** | v10.0.0 | v10.0.0 | User | lcm-governed |
| **`LCM_Supervision`** | Git | `NewStructure` | `5ebecc4` | clean | **governed** | v10.0.0 | v10.0.0 | User | lcm-governed |
| **`LCM_Tools`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `d12bf3e` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `457624b` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `f0986bc` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `b999170` | clean | **not-lcm** | - | - | User | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `4773dd4` | clean | **not-lcm** | - | - | User | standard-git |
| **`RollingCalendar`** | Git | `NewStructure` | `5b1bec1` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`TimeStamper`** | Git | `main` | `586f41d` | clean | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `NewStructure` | `b17a113` | clean | **governed** | v10.0.0 | v10.0.0 | **Admin** | lcm-governed |

