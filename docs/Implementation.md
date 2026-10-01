# Implementation Specification: Workspace Inventory & Configuration Management Engine

Module: docs/Implementation.md  
Purpose: Code-level catalog, data schemas, exported functions, tool parameters, and testing traceability for LCM_Inventory.  
Path: D:/Git_Repositories/LCM_Inventory/docs/Implementation.md  
Authors: Rolf, LCM_AI Engine  
Version: 7.0.0  
Status: Authoritative Implementation  
Date: 2026-09-19  

---

## 1. Directory Structure & File Taxonomy

```
LCM_Inventory/
├── .agents/
│   └── rules/                  # Canonical authoritative rule files (17 files)
├── data/
│   ├── artifacts/              # HTML presentation viewers (untracked)
│   ├── inventory.json          # Live multi-repo configuration audit manifest
│   ├── proposals/
│   │   └── proposals.json      # Canonical proposal ledger (single source of truth)
│   ├── readiness/              # Quality gate test output files
│   ├── reviews/                # Cryptographic review receipts (untracked)
│   └── staging/                # Transient patch and diff staging
├── docs/
│   ├── Architecture.md         # End-user & topology architecture spec
│   ├── Requirements.md         # Normative technical & invariant requirements spec
│   ├── Implementation.md       # Code catalog, schemas & exported cmdlets spec
│   ├── INVENTORY_DASHBOARD.md  # Live audit markdown dashboard
│   ├── CHANGE_REQUEST_INDEX.md # Historical proposal reference table
│   ├── CM_POLICIES.md          # CM governance policy summary
│   └── Proposals/              # Junction link or directory for proposal plans
├── logs/
│   └── cm_activity.log         # Append-only multi-repo audit & push log
├── modules/
│   └── WorkspaceCM.psm1        # Core Configuration Management engine module
└── tools/                      # Deterministic CLI tools & UI dashboard launchers
```

---

## 2. Core Module Architecture (`WorkspaceCM.psm1`)

The central PowerShell module [`modules/WorkspaceCM.psm1`](file:///D:/Git_Repositories/LCM_Inventory/modules/WorkspaceCM.psm1) exports the foundational CM cmdlets:

| Exported Cmdlet | Purpose & Contract | Key Parameters |
|:---|:---|:---|
| **`Get-WorkspaceInventory`** | Reads and returns the parsed object model from `data/inventory.json`. | `-Path <string>` |
| **`Update-WorkspaceInventory`** | Scans all child directories under `D:\Git_Repositories`, evaluates Git dirty state and LCM versions, and updates `data/inventory.json` and `docs/INVENTORY_DASHBOARD.md`. | `-WorkspaceRoot <string>` |
| **`Test-WorkspaceDrift`** | Evaluates workspace state against LCM governance baselines and returns drift diagnostic objects. | `-WorkspaceRoot <string>` |
| **`Get-ProposalLedger`** | Parses and validates `data/proposals/proposals.json`. | `-Path <string>` |
| **`Save-ProposalLedger`** | Atomically serializes proposal updates back to `proposals.json` with UTF-8 encoding. | `-Ledger <PSCustomObject>` |
| **`New-Proposal`** | Creates and registers a new proposal in `suggested` state with next auto-incremented ID. | `-Title <string>`, `-Scope <string>`, `-Author <string>` |
| **`Set-ProposalState`** | Transitions a proposal through lifecycle states (`suggested`, `approved`, `completed`, `pushed`, `rejected`). | `-Id <int>`, `-State <string>`, `-Note <string>` |

---

## 3. Tool Scripts Inventory

All tools in `tools/` conform to `RULE-PS-008` (Headers), `RULE-PS-009` (Logging), and `RULE-PS-010` (CLI Help):

| Tool Script | Role & Function | Key Parameters |
|:---|:---|:---|
| **`Invoke-BeyondCompareReview.ps1`** | Visual review gate for pre-commit diff inspection in Beyond Compare 5. | `-Repository <string>`, `-ForceInProcess`, `-Help` |
| **`Invoke-WorkspacePush.ps1`** | Multi-repo lockstep Git push engine with Gemini export and proposal state transition. | `-Reason <string>`, `-Repositories <string[]>`, `-DryRun`, `-Help` |
| **`Invoke-WorkspaceAudit.ps1`** | CLI runner for multi-repo audit scan and drift assessment. | `-Help` |
| **`Test-LCMRuleHealth.ps1`** | Validates NTFS junction integrity and rule header parity across all repositories. | `-Fix`, `-Help` |
| **`Show-CmControlHub.ps1`** | Interactive loopback web dashboard for complete LCM proposal and repository management. | `-Port <int>`, `-Help` |
| **`Show-LcmActiveLauncher.ps1`** | LCM Tool Explorer displaying all 192 workspace tools with category filtering and execution routing. | `-Help` |
| **`Show-WorkspaceReadiness.ps1`** | Workspace readiness rollup viewer displaying test suite passing status and review receipts. | `-Help` |
| **`Submit-ReviewResult.ps1`** | Programmatic acceptance hook recording review receipts into `data/reviews/`. | `-Repository <string>`, `-ReceiptPath <string>`, `-Help` |

---

## 4. Data Models & JSON Schemas

### Proposal Ledger Schema (`data/proposals/proposals.json`)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "version": "7.0.0",
  "updated_at": "2026-09-19 18:05:38",
  "proposals": [
    {
      "id": 156,
      "crp_id": "CRP-156",
      "timestamp": "2026-09-19 15:30:00",
      "title": "Standardize HTML Presentation Artifacts to data/artifacts/",
      "origin_repo": "LCM_Inventory",
      "state": "pushed",
      "progress_state": "pushed",
      "priority": "M",
      "author": "Rolf, LCM_AI",
      "details": "Relocate runtime HTML viewer generation to untracked data/artifacts/.",
      "plan_path": "LCM_Inventory/docs/Proposals/CRP-156-LCM-v7.5.2-Standardize-HTML-Presentation-Artifacts-To-Data-Artifacts.md",
      "pushed_at": "2026-09-19 18:05:33"
    }
  ]
}
```

### Inventory Manifest Schema (`data/inventory.json`)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "LCM Workspace Inventory",
  "generated_at": "2026-09-19 18:24:12",
  "workspace_ai_baseline": "7.0.0",
  "repositories": [
    {
      "RepositoryName": "LCM_Inventory",
      "Path": "D:\\Git_Repositories\\LCM_Inventory",
      "Classification": "governed",
      "GitStatus": "Git",
      "Branch": "main",
      "HeadCommit": "3d3c128",
      "DirtyState": "clean",
      "AheadBehind": "synced",
      "HasUnpushed": false,
      "LCMStatus": "governed",
      "AbsorbedLCMVersion": "7.0.0",
      "CurrentLCMVersion": "7.0.0",
      "ElevationRequired": false,
      "MinimumPrivilege": "User",
      "JunctionsHealthy": true
    }
  ]
}
```

<!-- FixDocumentation: CRP-196 Implementation -->
### 3.1 Documentation Reconciliation Tool

| Tool Script | Role & Function | Key Parameters |
|:---|:---|:---|
| **`Fix-Documentation.ps1`** | Reconciles explicit, repository-qualified CRP/BUG payloads into tripartite documents. | `<CRP/BUG scope>`, `-Apply`, `-OpenReview`, `-Trace` |
<!-- /FixDocumentation -->

