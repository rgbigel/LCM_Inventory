---
Proposal-ID: CRP-026
CR-ID: CR-2026-037
Scope: Workspace_Inventory
Version: v7.1.1
Affected-Repos: [Workspace_Inventory, .agents, Workspace_AI]
Status: In-Progress
Date: 2026-08-30
Author: rgbig
Target Scope: Workspace_Inventory / tools / governance
Affected Version Range: v7.1.1
Impacted Repositories: [Workspace_Inventory, .agents, Workspace_AI]
---

# CRP-026: Workspace Inventory Viewer Interactive Actions Suite, Non-Git Directory Visibility, and Data Versioning Exemption

## 1. Executive Summary & Intent
Enhance the Workspace Inventory Viewer web application (`WORKSPACE_INVENTORY_VIEWER.html` / `Show-WorkspaceInventoryApp.ps1`) to provide complete visibility over all workspace directories (including non-Git infrastructure and the `.lcd` platform engine) and equip each directory row with a standardized suite of interactive operational actions:
1. **📂 Explorer**: Open directory in Windows File Explorer.
2. **🛡️ Onboard**: Execute LCM governance onboarding (`LCMOnboardRepo.ps1`).
3. **🚫 Un-Git**: Strip `.git` metadata to convert a Git repository into a plain local folder.
4. **✏️ Rename**: Prompt for and safely rename workspace directories.
5. **🗑️ Delete**: Safely purge obsolete or unwanted workspace directories.

Additionally, formally codify the **Workspace_Inventory Data Versioning Exemption Invariant**: operational ledger mutations (`data/inventory.json`, `data/proposals/proposals.json`, `logs/cm_activity.log`) arising from standard workflow accounting do not constitute code or policy changes and therefore **do not increment `Workspace_Inventory`'s semantic version**.

---

## 2. Architectural Specification

### 2.1 Interactive Action Endpoints (Daemon Port 9876)

| Action | Target Payload | Behavior |
|:---|:---|:---|
| **📂 Open** | `{ "filePath": "<RepoPath>" }` $\to$ `POST /open` | Launches Windows File Explorer focused on the directory via desktop daemon. |
| **🛡️ Onboard** | `{ "command": "pwsh -File Workspace_AI/tools/Onboarding/LCMOnboardRepo.ps1 -RepositoryName <Name>" }` | Executes LCM onboarding wizard in interactive terminal. |
| **🚫 Un-Git** | `{ "command": "Remove-Item -LiteralPath '<RepoPath>\\.git' -Recurse -Force" }` | Strips Git tracking after confirmation. |
| **✏️ Rename** | Prompt new name $\to$ `{ "command": "Rename-Item -LiteralPath '<OldPath>' -NewName '<NewName>'" }` | Renames folder and triggers inventory re-audit. |
| **🗑️ Delete** | Confirm deletion $\to$ `{ "command": "Remove-Item -LiteralPath '<RepoPath>' -Recurse -Force" }` | Deletes directory and triggers inventory re-audit. |

### 2.2 Directory Visibility & Platform Inclusion
* Explicitly scan and list `.lcd`, `.agents`, `.copilot`, and all non-Git utility folders in the inventory dashboard.
* Provide quick filter tabs: **All Directories (27+)**, **Governed Repositories (12)**, **Standard Git (8)**, and **Non-Git / Infrastructure (7)**.

### 2.3 Data Versioning Exemption Invariant (`RULE-REV-007.3`)
* Regular operational writes to `Workspace_Inventory/data/inventory.json`, `Workspace_Inventory/data/proposals/proposals.json`, and `Workspace_Inventory/logs/cm_activity.log` do not increment semantic versioning.
* Semantic version increments (`+0.0.1`, `+0.1.0`) apply strictly when scripts (`tools/*.ps1`), modules (`modules/*.psm1`), specifications (`docs/*.md`), or governance rules are modified.

---

## 3. Verification & Quality Gates
* Run `Show-WorkspaceInventoryApp.ps1` to test interactive action buttons on Session 1.
* Verify `.lcd` is present with status and version.
* Run `Workspace_AI/tools/Test-WorkspaceReadiness.ps1` to ensure clean quality gate pass.

