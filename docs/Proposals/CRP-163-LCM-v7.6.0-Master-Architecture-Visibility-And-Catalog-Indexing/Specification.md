# Change Request Proposal: CRP-163

```yaml
CRP-ID: CRP-163
Title: Master Tripartite Architecture Visibility, Catalog Indexing & Cross-App Governance Focus
Scope: LCM Governance, LCM_Inventory & Governed Child Repositories
Baseline-Version: v7.6.0
Author: Rolf, LCM_AI Engine
Date: 2026-09-20
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: High
Impacted-Repositories:
  - LCM_Inventory
  - LCM_AI
  - Governed Child Repositories (Global)
```

---

## 1. Executive Summary & Problem Statement

In the Lifecycle Model (LCM) App-Centric Architecture system (CRP-048, CRP-158, CRP-161), repositories are decomposed into modular App slices (`App: 1`, `App: 2`, `App: 3`, etc.). However:
1. **Omission of Master Documents**: The App Catalog (`Get-LcmApps`, `Sync-LcmAppCatalog`, `apps.json`, and CM Control Hub `#appsModal`) exclusively indexed sliced child Apps, completely omitting the root **Master Documents** (`Architecture.md`, `Requirements.md`, `Implementation.md`) that govern the entire repository and define global system invariants.
2. **Invisible Base/Master Focus**: When active focus was set to foundational scope (`workon Master`, `workon Architecture`, `workon clear`), the UI showed "Focus: None (Base)", without highlighting or linking to the Master documents governing all Apps.
3. **Lack of Direct Master Inspection**: There was no mechanism in the App Catalog table to inspect or navigate to the master tripartite specifications.

**`CRP-163`** elevates the **Master Tripartite Architecture** to a first-class, prominent entry across all discovery tools, catalogs, CLI runners, and the CM Control Hub dashboard.

---

## 2. Technical Architecture & Invariants

### Invariant 1: Master Tripartite Architecture as Entry `0`
Every repository containing a `docs/` folder with root specifications `Architecture.md`, `Requirements.md`, or `Implementation.md` `MUST` have a distinguished **`Master`** entry (`id: "Master"`, `number: 0`, `is_master: true`, `doc_layout: "MasterRoot"`) in the App Catalog:
- **`arch_defined`**: Tracks presence of root `Architecture.md` (defining root topology and App index table).
- **`req_defined`**: Tracks presence of root `Requirements.md` (defining root system invariants).
- **`impl_defined`**: Tracks presence of root `Implementation.md` (defining root constituent mapping and contracts).

### Invariant 2: Explicit Active Focus on Master Architecture
`Set-ActiveAppContext` and `Invoke-ProposalAction.ps1 -Action workon` `MUST` recognize `Master`, `Architecture`, `Base`, `Root`, and `0`:
- Setting focus captures `app_id: 'Master'` and `app_title: 'Master Tripartite Architecture (Governing All Apps)'`.
- Clearing focus (`workon clear`) announces active focus on Master Architecture.

### Invariant 3: CM Control Hub Master Representation & Interactive Links
The CM Control Hub (`CM_CONTROL_HUB.html`) `MUST`:
- Render a dedicated **`🏛️ Master`** row per repository styled with distinctive purple branding.
- Provide interactive `A` · `R` · `I` badges opening each master specification directly in the Document Inspector modal.
- Provide a `🏛️ Focus Master` button and `📚 Master Docs` review button.
- Display a guidance banner explaining that Master Documents govern all child Apps.

---

## 3. Component Impact & File Topology

```text
LCM_Inventory/
├── docs/
│   └── Proposals/
│       └── CRP-163-LCM-v7.6.0-Master-Architecture-Visibility-And-Catalog-Indexing/
│           ├── Specification.md
│           ├── Implementation_Plan.md
│           └── Walkthrough.md
├── modules/
│   └── ProposalManager.psm1        # Master entry in Get-LcmApps, Set-ActiveAppContext, Format-LcmAppsTable
├── tools/
│   ├── Invoke-ProposalAction.ps1   # workon Master display support
│   └── Show-CmControlHub.ps1       # normalized doc keys in docsCache
├── assets/
│   └── CM_CONTROL_HUB.html         # Master row rendering, guidance banner, active focus badge
└── data/catalog/
    └── apps.json                   # Synchronized catalog including Master entries
```

---

## 4. Verification Plan

1. **Unit Tests**:
   - Verify `Get-LcmApps` outputs `Master` entry (`number: 0`) alongside child Apps.
   - Verify `Set-ActiveAppContext -Context 'Master'` and `Set-ActiveAppContext -Context 'Architecture'` both resolve cleanly.
   - Verify `Format-LcmAppsTable` highlights Master row on base focus.
   - All 21 tests in `ProposalManager.Tests.ps1` passing 100%.
2. **Catalog Synchronization**:
   - `Sync-LcmAppCatalog.ps1` compiles all 23 repositories with Master entries.
3. **Control Hub UI Verification**:
   - `Show-CmControlHub.ps1 -NoLaunch` compiles cleanly.
