---
Proposal-ID: CRP-054
CR-ID: CRP-054
Scope: LCM_Inventory
Version: v7.4.2
Affected-Repos: [LCM_Inventory, Git_Repositories]
Severity: Medium
Status: In-Progress
Date: 2026-09-02
Author: Rolf, LCM_AI
Target Scope: LCM_Inventory Tool Governance Scope & Data Exemption Split
Affected Version Range: v7.4.0 -> v7.4.2
Impacted Repositories: [LCM_Inventory, Git_Repositories]
---

# CRP-054: Clarify LCM_Inventory Tool Governance Scope — Privileged Subsystem Data Exemption vs. Tool Scrutiny

## 1. Executive Summary & Problem Statement
Currently, `RULE-LCM-004` states that `LCM_Inventory` is "the only exempt repository from visual BC5 review because it acts strictly as the tool/agent-controlled CM ledger". In addition, `ProposalManager.psm1` blanket skips `LCM_Inventory` (`if ($repoName -eq 'LCM_Inventory') { continue }`).

This creates a governance inconsistency:
1. **Unscrutinized Executable Code**: Permanent PowerShell scripts (`tools/*.ps1`), core modules (`modules/*.psm1`), and architectural documentation (`docs/*.md`) located within `LCM_Inventory` are committed and pushed without visual Beyond Compare 5 review gates.
2. **Conflation of Data and Code**: While dynamic configuration data (proposals ledger `data/proposals/proposals.json`, review receipts `data/reviews/*`, telemetry logs `logs/*`, and scratch assets `scratch/*`) are mechanical evidence auto-accepted under `RULE-EFF-001`, executable tools and modules are production software assets that require standard human-in-the-loop review.

---

## 2. Proposed Architecture & Scope of Changes

### 2.1 Amendment to RULE-LCM-004 (ProposalReviewFlowPolicy.md)
Update `RULE-LCM-004` to explicitly distinguish data exemption from tool scrutiny:
* **Auto-Accepted Data Exemption (`RULE-EFF-001`)**: Ledger files, audit receipts, telemetry logs, and scratch generation outputs (`data/`, `logs/`, `scratch/`) within `LCM_Inventory` are auto-accepted evidence and exempt from visual diff stops.
* **Executable Tool & Documentation Scrutiny**: Changes to permanent scripts, modules, and documentation within `LCM_Inventory` (`tools/`, `modules/`, `docs/`) are first-class governed LCM code assets subject to mandatory Beyond Compare 5 visual review gates (`Invoke-BeyondCompareReview.ps1 LCM_Inventory`).

### 2.2 Review Queue Discrimination in ProposalManager.psm1
Modify `Get-ReposUnderReview` in `LCM_Inventory/modules/ProposalManager.psm1`:
* Replace blanket repository skipping with path-aware discrimination.
* If `LCM_Inventory` contains uncommitted changes solely in `data/`, `logs/`, or `scratch/`, it is treated as data-exempt.
* If any uncommitted modifications exist in `tools/`, `modules/`, or `docs/`, `LCM_Inventory` is flagged as pending visual review (`Waiting for BC5 Review`).

---

## 3. Affected Components
* `LCM_Inventory/docs/Proposals/CRP-054-LCM-v7.4.2-Workspace-Inventory-Tool-Governance-Scope-And-Data-Exemption-Split.md`
* `.agents/rules/ProposalReviewFlowPolicy.md` (`RULE-LCM-004`)
* `LCM_Inventory/modules/ProposalManager.psm1` (`Get-ReposUnderReview`)
* `LCM_Inventory/data/proposals/proposals.json`
