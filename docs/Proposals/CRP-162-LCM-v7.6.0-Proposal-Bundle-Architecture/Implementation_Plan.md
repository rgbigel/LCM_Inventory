# Implementation Plan: CRP-162

```yaml
CRP-ID: CRP-162
Title: Proposal Bundle Directory Architecture, Dual Lifecycle, Git Object Document Retrieval, and Post-Push Working Tree Purge Engine
Scope: LCM Governance, LCM_Inventory, & Governed Child Repositories
Baseline-Version: v7.6.0
Author: Rolf, LCM_AI Engine
Date: 2026-09-20
Status: Processed
Plan-State: completed
Progress-State: completed
Priority: High
```

---

## 1. Technical Components & Architectural Topology

### Component 1: Proposal Manager Engine (`ProposalManager.psm1`)
- `New-WorkspaceProposal`: Scaffolds proposal bundle directories (`docs/Proposals/CRP-<nnn>-<Slug>/`) with `Specification.md`, `Implementation_Plan.md`, and `Walkthrough.md`.
- `Get-LcmProposalDocument`: Dual-mode document resolver (Live Working Tree -> Git commit object database via `git show <SHA>:<path>` -> Legacy flat file fallback).
- `Remove-LcmProposalBundle` (aliases `Purge-LcmPushedProposalBundle`, `Purge-Bundle`): Captures head commit SHA, updates ledger record, and removes working tree directory post-push.

### Component 2: CLI Proposal Action Runner (`Invoke-ProposalAction.ps1`)
- Added actions: `doc`, `docs`, `show-doc`, `purge-bundle`.
- Pure ASCII console output per `INVARIANT-RULES`.

### Component 3: CM Control Hub UI (`CM_CONTROL_HUB.html` & `Show-CmControlHub.ps1`)
- Tabbed proposal document viewer modal (`Specification`, `Implementation Plan`, `Walkthrough`).
- Live Working Tree (`🟢 Live`) vs Git Object (`🟣 Git Object: <SHA>`) status badges.
- Automatic caching of proposal bundle directories in `Show-CmControlHub.ps1`.

### Component 4: Governance Rule Codification
- `RULE-LCM-020` in `LCM_Inventory/.agents/rules/ProposalReviewFlowPolicy.md`.
- Quick-reference index updated in `AGENTS.md`.

---

## 2. Verification Plan & Test Strategy

1. **Unit Testing (`ProposalManager.Tests.ps1`)**:
   - Verify `New-WorkspaceProposal` creates bundle subdirectories with tripartite markdown files.
   - Verify `Get-LcmProposalDocument` reads live filesystem.
   - Verify `Get-LcmProposalDocument` extracts Git commit objects via `git show`.
   - Verify `Remove-LcmProposalBundle` cleans local working tree.
2. **Control Hub Compilation**:
   - `pwsh LCM_Inventory/tools/Show-CmControlHub.ps1 -NoLaunch` executes without error.
3. **Readiness Quality Gate**:
   - `pwsh LCM_Inventory/tools/Test-WorkspaceReadiness.ps1 -Repository LCM_Inventory` passes 100%.
