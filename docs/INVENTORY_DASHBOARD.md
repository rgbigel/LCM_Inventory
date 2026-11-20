# Workspace Configuration Management (CM) Inventory Dashboard

Module: docs/INVENTORY_DASHBOARD.md
Generated: 2026-11-20 16:03:20
Global Baseline Version: **v10.8.4** (Source: LCM_AI)

---

## 1. Summary Statistics

| Metric | Count | Description |
| :--- | :---: | :--- |
| **Total Directories Audited** | **32** | All child directories under D:\Git_Repositories\ |
| **Active Design Workshop** | **1** | LCM_AI (v10.8.4) |
| **CM Repository** | **1** | LCM_Inventory |
| **LCM Governed / Candidates** | **10** | Actively governed under LCM |
| **Elevation Required Repositories** | **8** | Repositories requiring Administrator privileges |
| **Standard Git Repositories** | **12** | Un-onboarded Git repos |
| **Non-Git Component Folders** | **5** | Non-Git folders (git.ignoredRepositories) |
| **Retired Legacy Baselines** | **2** | Workspace_AC, Workspace_GC |

---

## 2. Comprehensive Repository CM Matrix

| Repository Name | Git Status | Branch | HEAD SHA | Working Copy | LCM Status | Absorbed Ver | Current Ver | Elevation | Classification |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`.agents`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.claude`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.copilot`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.git`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.githooks`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`.github`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.venv`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`.vscode`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | parent-infra |
| **`AuthorizeMasterUser`** | Git | `NewStructure` | `a032e42` | clean | **governed** | v10.8.4 | v10.8.4 | **Admin** | lcm-governed |
| **`BackgroundModifier`** | Git | `NewStructure` | `2c50ed5` | clean | **governed** | v10.8.4 | v10.8.4 | **Admin** | lcm-governed |
| **`BGMSAMVInv`** | Git | `NewStructure` | `8cf1a76` | clean | **governed** | v10.8.4 | v10.8.4 | User | lcm-governed |
| **`BootEntryManager`** | Git | `NewStructure` | `22abb0f` | clean | **governed** | v10.8.4 | v10.8.4 | **Admin** | lcm-governed |
| **`docs`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`HaSSD06`** | Git | `NewStructure` | `2fffb86` | clean | **not-lcm** | - | - | User | standard-git |
| **`HaSSD06_Inventory`** | Git | `NewStructure` | `c0a8c4b` | clean | **not-lcm** | - | - | User | standard-git |
| **`InstallFonts`** | Git | `main` | `32f5402` | clean | **not-lcm** | - | - | User | standard-git |
| **`LCM_AI`** | Git | `main` | `f0f1d79` | clean | **governed** | v10.8.4 | v10.8.4 | User | active-design-workshop |
| **`LCM_Inventory`** | Git | `main` | `f29af66` | modified (18 files) | **governed** | v10.8.4 | v10.8.4 | **Admin** | configuration-management |
| **`LCM_Shared`** | Git | `NewStructure` | `79e319a` | clean | **governed** | v10.8.4 | v10.8.4 | User | lcm-governed |
| **`LCM_Supervision`** | Git | `NewStructure` | `9183767` | clean | **governed** | v10.8.4 | v10.8.4 | User | lcm-governed |
| **`LCM_Tools`** | Git | `main` | `fa49874` | clean | **not-lcm** | - | - | User | standard-git |
| **`MacriumTemplateUpdater`** | Git | `main` | `aa2c472` | clean | **not-lcm** | - | - | User | standard-git |
| **`MSG file conversion`** | Git | `main` | `da554c3` | clean | **not-lcm** | - | - | User | standard-git |
| **`NextBootTray`** | Git | `main` | `cd50cac` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`OneDriveMaintenance`** | Git | `main` | `ffa53a0` | clean | **not-lcm** | - | - | User | standard-git |
| **`OutlookVBAConversion`** | Git | `main` | `6c39024` | clean | **not-lcm** | - | - | User | standard-git |
| **`ReEnableRadeonRx580`** | Git | `main` | `3a23d0f` | clean | **not-lcm** | - | - | User | standard-git |
| **`RollingCalendar`** | Git | `NewStructure` | `d869fc9` | clean | **not-lcm** | - | - | **Admin** | standard-git |
| **`scratch`** | Non-Git | `-` | `-` | clean | **not-lcm** | - | - | User | non-git |
| **`SystemConfiguration`** | Git | `main` | `c1433ec` | clean | **governed** | v10.8.4 | v10.8.4 | **Admin** | lcm-governed |
| **`TimeStamper`** | Git | `main` | `60fe61f` | clean | **not-lcm** | - | - | User | standard-git |
| **`VolumeInventory`** | Git | `NewStructure` | `8311626` | clean | **governed** | v10.8.4 | v10.8.4 | **Admin** | lcm-governed |

