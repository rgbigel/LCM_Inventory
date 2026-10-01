# Requirements Specification: Workspace Inventory & Configuration Management Engine

Module: docs/Requirements.md  
Purpose: Normative technical requirements, environmental prerequisites, safety boundaries, and compliance constraints for Workspace_Inventory.  
Path: D:/Git_Repositories/Workspace_Inventory/docs/Requirements.md  
Authors: Rolf, Workspace_AI Engine  
Version: 7.0.0  
Status: Authoritative Requirements  
Date: 2026-09-19  

---

## 1. Environmental Prerequisites & Platform Constraints

1. **PowerShell Runtime**: Must execute on **PowerShell 7.4+ (`pwsh`)** with `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`. Windows PowerShell 5.1 is prohibited.
2. **Operating System**: Windows 11 64-bit with NTFS file system supporting symbolic links and volume mount junctions.
3. **Execution Privilege**: Default un-elevated (User) context. Tools requiring administrator privileges must route through `Start-ScriptProcessElevated.ps1` with the non-auto-close invariant (`RULE-ELEV-001` - `006`).
4. **Encoding & Line Endings**: UTF-8 without BOM, CRLF line endings, 2-space JSON and Markdown indentation (`INVARIANT-RULES`).

---

## 2. Normative Invariants & CM Governance Rules

### REQ-WINV-001: Review Gate Enforcement (`RULE-REV-001`)
- No automated tool or AI assistant `MAY` commit changes to Git repositories without explicit operator visual review via Beyond Compare 5 (`Invoke-BeyondCompareReview.ps1`).
- Direct invocation of `git commit` outside the review runner is strictly prohibited during interactive development.

### REQ-WINV-002: Audit Receipt Generation & Persistence (`RULE-REV-003`)
- Every approved commit `MUST` produce an immutable audit receipt in `Workspace_Inventory/data/reviews/review_<Repo>_<timestamp>.json`.
- Receipts must record repository name, target branch, commit hash, commit message, and changed file paths.

### REQ-WINV-003: Single Source of Truth for Proposals (`RULE-LCM-001`)
- All change requests, bug fixes, and feature proposals `MUST` be registered in `Workspace_Inventory/data/proposals/proposals.json`.
- Proposals must contain: unique integer `id`, `title`, `state`, `origin_repo`, `priority`, and formal `plan_path`.
- **Legacy Backward Compatibility Guard**: When parsing legacy proposals, imported historical records, or external CRPs where `origin_repo` is absent or null, tools and consumers `MUST NOT` throw runtime exceptions or break proposal ingestion. They `MUST` fallback gracefully to `'Workspace_Inventory'` (or root repository context) and log a non-fatal warning for metadata backfill.

### REQ-WINV-004: Workspace Audit & Drift Detection (`RULE-EFF-001`)
- `Invoke-WorkspaceAudit.ps1` `MUST` inspect all LCM-governed repositories under `D:\Git_Repositories`, assessing:
  - Git repository validity and current branch.
  - Working tree dirty state (clean vs uncommitted changes).
  - Tracking status (ahead/behind remote origin).
  - Absorbed LCM baseline parity against `GlobalLCMVersion`.
  - NTFS junction health pointing to `.agents/rules`.

### REQ-WINV-005: Lockstep Multi-Repository Push (`RULE-LCM-013`)
- `Invoke-WorkspacePush.ps1` `MUST` conduct pre-push validation (Gemini rules export and tool catalog synchronization).
- It `MUST` iterate across all ahead repositories, execute `git push origin <branch>`, log structured audit records to `logs/cm_activity.log`, and transition completed proposals to `pushed`.
- **Directional Lockstep Invariant (`SharedModules` <-> `Workspace_Inventory`)**: Any code, atom, or documentation change in `SharedModules` updates its repository version and commit hash, which `MUST` be reflected in `Workspace_Inventory` (`inventory.json`). Therefore, pushing `SharedModules` without simultaneously pushing `Workspace_Inventory` is prohibited. Conversely, pushing `Workspace_Inventory` in isolation is valid for routine inventory data, audit receipts, and telemetry commits, *unless* an inventory tool change or contract update modifies/inspects `SharedModules`, which again couples both in lockstep.

### REQ-WINV-006: Runtime Presentation Artifact Isolation (`RULE-DSP-008` / `CRP-156`)
- All generated HTML dashboard reports, document viewers, and temporary interactive tables `MUST` be written to `data/artifacts/` or `data/staging/`.
- Generated HTML runtime views `MUST NOT` be committed to repository `docs/` directories.

---

## 3. UI/UX Display Standards Compliance

All interactive viewers in `Workspace_Inventory` (such as `Show-CmControlHub.ps1`, `Show-WorkspaceInventoryApp.ps1`, `Show-WorkspaceReadiness.ps1`) `MUST` conform to [`DisplayStandardsPolicy.md`](file:///D:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md):
1. **Canonical Token Architecture**: Must inherit styles from `StandardTableDisplay.css` (Glassmorphic dark mode, hsl custom properties).
2. **Double-Row Sticky Table Headers**: Row 1 for column titles and multi-column sorting; Row 2 for live filter inputs.
3. **Action Logging Drawer**: Must provide collapsible floating audit drawer capturing all desktop dispatches with timestamps and exit codes.
4. **Desktop Dispatch Routing**: Must invoke native applications via background runners without terminal focus stealing (`RULE-PS-012`).

---

## 4. Constituent Module Inspection & Contract Governance Tools [Draft Concept]

> [!NOTE]
> **Draft Status Warning**: This section represents an exploratory architectural working concept and is **currently NOT the authoritative source of truth**. It defines planned inspection tools hosted and versioned by `Workspace_Inventory` to audit external satellite modules (such as `SharedModules`).

### REQ-WINV-007: Contract Verification Engine (`ShowContracts`)
- `Workspace_Inventory` `MUST` host `Show-Contracts.ps1` (`ShowContracts`) to inspect, visualize, and verify public contract specifications, schema invariants, parameter assertions, and return-type expectations across constituent modules.
- It `MUST` audit consuming repositories for contract adherence and detect drift between declared contracts and consumer usage.

### REQ-WINV-008: Interface & Module Structure Discovery (`ShowInterfaces`, `ShowModules`)
- `Workspace_Inventory` `MUST` host `Show-Interfaces.ps1` (`ShowInterfaces`) to enumerate exported PowerShell functions, cmdlets, classes, and parameter bindings across workspace modules.
- `Workspace_Inventory` `MUST` host `Show-Modules.ps1` (`ShowModules`) to map manifests (`.psd1`), root scripts (`.psm1`), dependency trees, and load order hierarchies.

### REQ-WINV-009: Granular Atom Inventory (`ShowAtoms`)
- `Workspace_Inventory` `MUST` host `Show-Atoms.ps1` (`ShowAtoms`) to catalogue pure, reusable atomic functions ("Atoms") with their test coverage, Pester test links, and consumption metrics.

### REQ-WINV-010: Constituent Component Version Registry
- `Workspace_Inventory` `MUST` maintain an authoritative registry (`inventory.json`) recording the exact versions, commit hashes, and dependency states of all external satellite modules (e.g., `SharedModules`), while allowing each satellite module repository to maintain its own independent source code versioning lifecycle.

<!-- FixDocumentation: CRP-196 Requirements -->
### REQ-WINV-011: Scoped Documentation Reconciliation

`FixDocumentation` MUST default to dry-run, accept only explicit CRP/BUG
identifiers, and apply only declared fenced payloads. Applied changes MUST carry
provenance, produce an operational receipt, and undergo BCompare review before
commit.
<!-- /FixDocumentation -->

