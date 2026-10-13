# Master Change Request (CR) & Bundle Index

Module: docs/CHANGE_REQUEST_INDEX.md
Updated: 2026-10-13 15:22:57
Storage Architecture: **NTFS Junction Mirrored (1 File per CR)**
Total Tracked CRs: **16** | Bundles: **2**

---

## 1. Change Request Bundles (Batch Test Suites)

| Bundle ID | Bundle Name | Target Ver | Test Suite | Status | Included CRs |
| :--- | :--- | :---: | :--- | :---: | :--- |
| **`BUNDLE-2026-01`** | LCM 10.0.0 Baseline Milestone | 10.0.0 | `Test-WorkspaceReadiness.ps1` | **verified** | `CR-2026-001`, `CR-2026-002`, `CR-2026-003`, `CR-2026-004`, `CR-2026-005`, `CR-2026-006`, `CR-2026-007`, `CR-2026-008`, `CR-2026-009`, `CR-2026-010` |
| **`BUNDLE-2026-02`** | LCM_Inventory CM Initialization | 10.0.0 | `Invoke-WorkspaceAudit.ps1` | **implemented** | `CR-2026-011` |

---

## 2. Individual Change Requests (1 File per CR)

| CR ID | Origin Repo | Bundle | Title | Status | Target Ver | Author | Created |
| :--- | :--- | :---: | :--- | :---: | :---: | :--- | :--- |
| **`20260813-lifecycle-powershell-logging`** | `Unknown` | - | 20260813-lifecycle-powershell-logging | **proposed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-001`** | `LCM_AI` | `BUNDLE-2026-01` | Initialize LCM Proposal 2-level requirements architecture | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-002`** | `LCM_AI` | `BUNDLE-2026-01` | Purge legacy crash recovery prefixes from state logs | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-003`** | `LCM_AI` | `BUNDLE-2026-01` | Consolidate Test-WorkspaceReadiness and WorkspaceQualityGates | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-004`** | `LCM_AI` | `BUNDLE-2026-01` | Align git.ignoredRepositories across settings, docs, and quality gates | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-005`** | `LCM_AI` | `BUNDLE-2026-01` | Design and scaffold 4-Phase LCM Onboarding Engine | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-006`** | `LCM_AI` | `BUNDLE-2026-01` | Codify Working scratchpad and .agents/skills standard | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-007`** | `LCM_AI` | `BUNDLE-2026-01` | Implement DryRun simulation and Update mode in LCMOnboarding | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-008`** | `LCM_AI` | `BUNDLE-2026-01` | Reconcile authority order in Workspace-Rules.md and whitelist docs/Logs | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-009`** | `LCM_AI` | `BUNDLE-2026-01` | Codify Junction Link Magic visual GUI and cross-volume link standard | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-010`** | `LCM_AI` | `BUNDLE-2026-01` | Bump to LCM pre-release Version 10.0.0 and create repository inventory matrix | **closed** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-011`** | `LCM_Inventory` | `BUNDLE-2026-02` | Establish LCM_Inventory as authoritative CM system | **implemented** | 10.0.0 | Rolf | 2026-10-13 |
| **`CR-2026-012`** | `LCM_Inventory` | `BUNDLE-2026-03` | Implement LCM Two-Tier Proposal and Review Governance Engine | **implemented** | 10.0.0 | Rolf | 2026-10-13 15:20:00 |
| **`CR-20260815_231129`** | `VolumeInventory` | - | Upgrade VolumeInventory to LCM Version 10.0.0 | **implemented** | 10.0.0 | Rolf | 2026-10-13 23:11:29 |
| **`CR-20260816_121058`** | `BackgroundModifier` | - | Upgrade BackgroundModifier to LCM Version 10.0.0 | **implemented** | 10.0.0 | Rolf | 2026-10-13 12:10:58 |
| **`README`** | `Unknown` | - | README | **proposed** | 10.0.0 | Rolf | 2026-10-13 |

