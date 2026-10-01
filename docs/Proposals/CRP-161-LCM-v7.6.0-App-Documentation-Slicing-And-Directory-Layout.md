# Change Request Proposal Specification: CRP-161
# App Documentation Slicing, Directory Layout (docs/App#<N>-<Slug>/), and Migration Engine (SplitDocs)

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-161` |
| **Lifecycle State** | `SUGGESTED` |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | Global LCM Governance, `RULE-DOC-007`, `ProposalManager.psm1`, `Split-LcmArchitectureToApps.ps1`, `Split-LcmAppDocs.ps1`, `Invoke-ProposalAction.ps1` |
| **Author** | Rolf, LCM_AI Intake |
| **Date** | 2026-09-20 |
| **Version Impact** | `v7.6.0` |
| **Severity / Priority** | High / Normal |

---

## 1. Problem Statement & Motivation

1. **In-Document vs Directory Partitioning**:
   - `CRP-048` introduced modular App-Centric tripartite architecture (`App: #`) partitioned within root tripartite files (`Architecture.md`, `Requirements.md`, `Implementation.md`).
   - For multi-capability repositories with comprehensive documentation, maintaining all App specifications within single monolithic root files can become difficult to navigate and maintain.

2. **Naming & Directory Structure Optimization**:
   - The initial prototype utilized an intermediate `docs/apps/` subfolder and a hyphenated naming convention (`App-1-<Slug>`).
   - The optimal, canonical structure requires placing App directories **directly under `docs/`** with explicit hashtag numbering: **`docs/App#<N>-<Slug>/`** (e.g. `docs/App#1-SystemIdentityStateCaptureEngine/`).
   - Eliminating the `docs/apps/` wrapping directory reduces folder nesting depth and aligns folder names directly with the `App: #` / `App#1` taxonomy.

3. **Migration & Tooling Requirements**:
   - Developers require an optional parameter `-SplitDocs` (default: `$false`) when slicing architectures (`Split-LcmArchitectureToApps.ps1`) or creating new Apps (`New-LcmApp`).
   - A dedicated migration cmdlet `Split-LcmAppDocs` (alias `SplitDocs`, action `split-docs`) is required to convert existing in-document repositories into dedicated `docs/App#<N>-<Slug>/` structures without manual file editing.

---

## 2. Proposed Architectural Solution

### 2.1 Canonical Directory Layout Standard

When an App-sliced repository uses directory separation, its files `MUST` adhere to the following physical layout:

```text
<RepositoryRoot>/
└── docs/
    ├── Architecture.md             # Root architecture + App Subsystems Index Table
    ├── Requirements.md             # Root requirements & baseline invariants
    ├── Implementation.md           # Root implementation & system boundaries
    ├── App#1-<Slug>/               # Dedicated App 1 Directory (Directly under docs/)
    │   ├── Architecture.md         # App 1 concept, user mental model, mermaid diagram
    │   ├── Requirements.md         # App 1 normative requirements & boundaries
    │   └── Implementation.md       # App 1 constituent manifest table & contracts
    ├── App#2-<Slug>/               # Dedicated App 2 Directory
    │   ├── Architecture.md
    │   ├── Requirements.md
    │   └── Implementation.md
    └── App#<N>-<Slug>/
        ├── Architecture.md
        ├── Requirements.md
        └── Implementation.md
```

### 2.2 Root `Architecture.md` Index Table

The root `Architecture.md` `MUST` maintain an authoritative **App Subsystems & Sliced Specifications** index table linking to each child App document:

```markdown
## App Subsystems & Sliced Specifications
The following modular App slices are documented in dedicated subdirectories per RULE-DOC-007:

| App ID | Title | Directory | Sliced Specifications |
|:---|:---|:---|:---|
| App: 1 | System Identity & State Capture Engine | [`docs/App#1-SystemIdentityStateCaptureEngine/`](file:///docs/App#1-SystemIdentityStateCaptureEngine) | [Arch](file:///docs/App#1-SystemIdentityStateCaptureEngine/Architecture.md) · [Req](file:///docs/App#1-SystemIdentityStateCaptureEngine/Requirements.md) · [Impl](file:///docs/App#1-SystemIdentityStateCaptureEngine/Implementation.md) |
| App: 2 | Telemetry Rendering & Skin Engine | [`docs/App#2-TelemetryRenderingSkinEngine/`](file:///docs/App#2-TelemetryRenderingSkinEngine) | [Arch](file:///docs/App#2-TelemetryRenderingSkinEngine/Architecture.md) · [Req](file:///docs/App#2-TelemetryRenderingSkinEngine/Requirements.md) · [Impl](file:///docs/App#2-TelemetryRenderingSkinEngine/Implementation.md) |
```

---

## 3. Tooling & Governance Specification

### 3.1 Parameter `-SplitDocs` (Default: `$false`)
- **`New-LcmApp`**: `New-LcmApp -Repo <Repo> -Title <Title> [-SplitDocs]`
- **`Split-LcmArchitectureToApps.ps1`**: `pwsh LCM_Inventory/tools/Split-LcmArchitectureToApps.ps1 -Repo <Repo> [-SplitDocs]`

### 3.2 Migration Engine `Split-LcmAppDocs` (`SplitDocs`)
- **Cmdlet**: `Split-LcmAppDocs -Repo <Repo> [-WorkspaceRoot <Path>] [-WhatIf]`
- **Standalone CLI**: [`LCM_Inventory/tools/Split-LcmAppDocs.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Split-LcmAppDocs.ps1)
- **Invoke-ProposalAction Dispatcher**: `pwsh LCM_Inventory/tools/Invoke-ProposalAction.ps1 -Action split-docs -TargetRepo <Repo>`

**Execution Flow**:
1. Parses in-document `## App: # - <Title>` sections from root `Architecture.md`, `Requirements.md`, `Implementation.md`.
2. Extracts root preambles.
3. Generates dedicated `docs/App#<N>-<Slug>/` directories directly under `docs/`.
4. Writes dedicated `Architecture.md`, `Requirements.md`, and `Implementation.md` per App.
5. Cleans root files and appends the formatted App Subsystems Index Table to root `Architecture.md`.
6. Re-synchronizes `data/catalog/apps.json`.

### 3.3 Rule Codification (`RULE-DOC-007`)
Update `DocumentationStandardsPolicy.md` to formalize:
1. Directory separation standard (`docs/App#<N>-<Slug>/` directly under `docs/`).
2. Prohibition of intermediate `docs/apps/` nesting.
3. Root `Architecture.md` App index table invariant.

---

## 4. Verification & Testing Plan

1. **Unit Tests**:
   - `Get-LcmApps` discovery of `docs/App#<N>-<Slug>/` directories.
   - `New-LcmApp -SplitDocs` scaffolding under `docs/App#<N>-<Slug>/`.
   - `Split-LcmAppDocs` migration of in-document sections to `docs/App#<N>-<Slug>/`.
2. **Repository Validation (`BackgroundModifier`)**:
   - Restructure `BackgroundModifier` to `docs/App#1-...` through `docs/App#4-...` directly under `docs/`.
   - Validate `BackgroundModifier/tools/Test-RepoReadiness.ps1` returns `OK`.
   - Validate `Test-LCMRuleHealth.ps1` returns 100% compliance across all 24 repositories.
