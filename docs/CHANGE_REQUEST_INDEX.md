# Master Change Request (CR) & Bundle Index

Module: docs/CHANGE_REQUEST_INDEX.md
Updated: 2026-08-15 23:13:12
Storage Architecture: **NTFS Junction Mirrored (1 File per CR)**
Total Tracked CRs: **14** | Bundles: **2**

---

## 1. Change Request Bundles (Batch Test Suites)

| Bundle ID | Bundle Name | Target Ver | Test Suite | Status | Included CRs |
| :--- | :--- | :---: | :--- | :---: | :--- |
| **`BUNDLE-2026-01`** | LCM v4.1.0 Baseline Milestone | v4.1.0 | `Test-WorkspaceReadiness.ps1` | **verified** | `CR-2026-001`, `CR-2026-002`, `CR-2026-003`, `CR-2026-004`, `CR-2026-005`, `CR-2026-006`, `CR-2026-007`, `CR-2026-008`, `CR-2026-009`, `CR-2026-010` |
| **`BUNDLE-2026-02`** | Workspace_Inventory CM Initialization | v4.1.0 | `Invoke-WorkspaceAudit.ps1` | **implemented** | `CR-2026-011` |

---

## 2. Individual Change Requests (1 File per CR)

| CR ID | Origin Repo | Bundle | Title | Status | Target Ver | Author | Created |
| :--- | :--- | :---: | :--- | :---: | :---: | :--- | :--- |
| **`20260813-lifecycle-powershell-logging`** | `Unknown` | - | 20260813-lifecycle-powershell-logging | **proposed** | v4.1.0 | Rolf | 2026-08-13 |
| **`CR-2026-001`** | `Workspace_AI` | `BUNDLE-2026-01` | Initialize LCM Proposal 2-level requirements architecture | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-002`** | `Workspace_AI` | `BUNDLE-2026-01` | Purge legacy crash recovery prefixes from state logs | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-003`** | `Workspace_AI` | `BUNDLE-2026-01` | Consolidate Test-WorkspaceReadiness and WorkspaceQualityGates | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-004`** | `Workspace_AI` | `BUNDLE-2026-01` | Align git.ignoredRepositories across settings, docs, and quality gates | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-005`** | `Workspace_AI` | `BUNDLE-2026-01` | Design and scaffold 4-Phase LCM Onboarding Engine | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-006`** | `Workspace_AI` | `BUNDLE-2026-01` | Codify Working scratchpad and .agents/skills standard | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-007`** | `Workspace_AI` | `BUNDLE-2026-01` | Implement DryRun simulation and Update mode in LCMOnboarding | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-008`** | `Workspace_AI` | `BUNDLE-2026-01` | Reconcile authority order in Workspace-Rules.md and whitelist docs/Logs | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-009`** | `Workspace_AI` | `BUNDLE-2026-01` | Codify Junction Link Magic visual GUI and cross-volume link standard | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-010`** | `Workspace_AI` | `BUNDLE-2026-01` | Bump to LCM pre-release Version 4.1.0 and create repository inventory matrix | **closed** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-2026-011`** | `Workspace_Inventory` | `BUNDLE-2026-02` | Establish Workspace_Inventory as authoritative CM system | **implemented** | v4.1.0 | Rolf | 2026-08-15 |
| **`CR-20260815_231129`** | `VolumeInventory` | - | Upgrade VolumeInventory to LCM Version 4.1.0 | **implemented** | v4.1.0 | Rolf | 2026-08-15 23:11:29 |
| **`README`** | `Unknown` | - | README | **proposed** | v4.1.0 | Rolf | 2026-08-13 |

