# Change Request Proposal: CRP-162

```yaml
CRP-ID: CRP-162
Title: Proposal Bundle Directory Architecture, Dual Lifecycle, Git Object Document Retrieval, and Post-Push Working Tree Purge Engine
Scope: LCM Governance, Workspace_Inventory, & Governed Child Repositories
Baseline-Version: v7.6.0
Author: Rolf, Workspace_AI Engine
Date: 2026-09-20
Status: Processed
Plan-State: completed
Progress-State: completed
Priority: High
Impacted-Repositories:
  - Workspace_Inventory
  - Workspace_AI
  - Governed Child Repositories (Global)
```

---

## 1. Executive Summary & Intent

Currently, proposal specifications across the workspace are stored as flat Markdown files in `docs/Proposals/`, while implementation plans and walkthroughs are archived separately in `Workspace_Inventory/data/proposals/plans/`. As repositories grow, this results in:
1. **Directory Clutter**: Dozens of flat proposal files accumulate across repositories.
2. **Scattered Artifacts**: A single proposal's specification, plan, and walkthrough are stored in disconnected locations.
3. **Working Tree Residue**: Completed proposals permanently linger in local child repositories even after being merged and pushed to GitHub, causing grep and search pollution.

**`CRP-162`** introduces the **Proposal Bundle Directory Architecture** and **Git Object Dual Lifecycle**:
- **Directory-per-Proposal Bundles**: Every proposal (whether LCM governance or child repo domain feature) is structured inside a dedicated subdirectory:
  `docs/Proposals/CRP-nnn-[Scope]-[Version]-[Slug]/` containing `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
- **Pre-Push Working Tree Availability**: While active, the proposal bundle lives on disk and is directly accessible to developers, tools, and the CM Control Hub.
- **Post-Push Working Tree Purge**: Upon `Invoke-WorkspacePush.ps1`, the commit SHA is recorded in `proposals.json`, the changes are pushed to GitHub, and the completed proposal folder is purged from the local working tree.
- **Post-Push Git Object Document Access**: `Workspace_Inventory` and CM Control Hub retrieve purged proposal documents on-demand using instant, local Git object extraction (`git show <SHA>:<path>`) or direct GitHub links.

---

## 2. Directory & Component Topology

### Pre-Push Layout (Active Development)
```text
<RepositoryRoot>/
└── docs/
    └── Proposals/
        └── CRP-162-LCM-v7.6.0-Proposal-Bundle-Architecture/
            ├── Specification.md       # Requirements, intent, architecture
            ├── Implementation_Plan.md # Technical diffs, component plans, tests
            └── Walkthrough.md         # Verification evidence, receipts, logs
```

### Post-Push Ledger Record (`proposals.json`)
```json
{
  "id": 162,
  "crp_id": "CRP-162",
  "origin_repo": "Workspace_Inventory",
  "state": "completed",
  "progress_state": "completed",
  "bundle_dir": "docs/Proposals/CRP-162-LCM-v7.6.0-Proposal-Bundle-Architecture",
  "docs": {
    "specification": "docs/Proposals/CRP-162-LCM-v7.6.0-Proposal-Bundle-Architecture/Specification.md",
    "plan": "docs/Proposals/CRP-162-LCM-v7.6.0-Proposal-Bundle-Architecture/Implementation_Plan.md",
    "walkthrough": "docs/Proposals/CRP-162-LCM-v7.6.0-Proposal-Bundle-Architecture/Walkthrough.md"
  }
}
```

---

## 3. Technical Requirements & Invariants

### Invariant 1: Tripartite Proposal Bundle Parity
Every proposal `MUST` maintain internal tripartite separation:
- `Specification.md` (Domain requirements & architecture decisions)
- `Implementation_Plan.md` (Execution plan & verification scope)
- `Walkthrough.md` (Execution evidence & test receipts)

### Invariant 2: Zero-Residue Working Tree on Push
When `Invoke-WorkspacePush.ps1` completes a remote push:
1. It records `commit_sha` and `github_url` in `proposals.json`.
2. It purges the local `docs/Proposals/CRP-nnn-[Slug]/` working tree folder via a clean Git commit.
3. The local repository retains 0 dead proposal folders.

### Invariant 3: Universal Dual-Mode Document Retrieval (`Get-LcmProposalDocument`)
The CM engine `MUST` seamlessly resolve proposal documents across both lifecycle states:
- If `Test-Path <LocalPath>` is `$true` -> Read local filesystem (Pre-Push).
- If `<LocalPath>` is absent and `commit_sha` is present -> Extract from local Git object database via `git -C <Repo> show <SHA>:<path>` (Post-Push).

### Invariant 4: CM Control Hub Proposal Document Inspector
CM Control Hub (`CM_CONTROL_HUB.html`) `MUST` provide:
- A `Docs` action button per proposal row with status badges (`Live` / `Git Object: <SHA>`).
- A tabbed Proposal Document Inspector modal rendering `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
