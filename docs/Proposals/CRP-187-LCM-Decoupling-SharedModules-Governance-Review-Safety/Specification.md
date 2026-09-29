# Change Request Proposal: CRP-187

## Metadata Header
* **Proposal ID**: `CRP-187`
* **Title**: LCM Runtime Decoupling, SharedModules Governance Integration, and Editor Review Safety Invariant
* **Author**: Rolf, Antigravity AI Assistant
* **Date**: 2026-09-28
* **Status**: In-Progress
* **Target Repositories**: `D:\Git_Repositories` (Root), `Workspace_Inventory`, `Workspace_AI`, `SharedModules`
* **App Context**: `A7` (Proposal Management / LCM Hub) & `A1` (Subsystems & Governance Engine)
* **Lifecycle State**: In-Progress (DOIT Mode activated)

---

## 1. Executive Summary & Intent
This comprehensive proposal formalizes the structural decoupling of operational runtime data from the `.lcm` repository container, decouples legacy archives from active workspace tooling, restores `SharedModules` to the authoritative LCM subsystem matrix under draft governance by `Workspace_Inventory`, synthesizes session failure modes and Data Atoms into formal engineering documentation, and establishes `RULE-LCM-022` to eliminate multi-review editor buffer collisions.

---

## 2. Problem Statement
1. **Runtime Namespace Sprawl in `.lcm`**:
   - Runtime operations logged directly to `.lcm/logs/` and `.lcm/scratch/`, causing search slowdowns and coupling volatile telemetry to the core LCM tooling codebase.
   - An orphaned, obsolete directory `D:\Workspace_Inventory` existed alongside the governed repository.
2. **Ambiguous Archive Boundaries**:
   - `D:\Git_Repositories\Archives` was loosely referenced in active tools (`DaemonActionController.ps1`, `lcm-tool-explorer.js`, `LcmToolCatalog.psm1`) as if it were a functional subsystem, violating the principle of an isolated junk yard.
3. **Exclusion of `SharedModules` from Subsystem Dashboards**:
   - `Show-Subsystems.ps1` explicitly filtered out `SharedModules`, obscuring a governed, version-controlled library repository from workspace visibility.
   - Lack of documented inspection tool requirements (`ShowContracts`, `ShowInterfaces`, `ShowModules`, `ShowAtoms`) and system of record versioning boundaries.
4. **Tool Catalog ShortName Collision & Recursion**:
   - Repeated regex prefixing in `Update-ToolCatalog.ps1` produced runaway prefixes (`LCMLCMLCM...ClearBCReviewTemp.cmd`).
5. **IDE Multi-Review Editor Collisions**:
   - Rapid back-to-back edits on open files created stacked, ambiguous "Accept" diff decorations in the IDE editor, creating risks of out-of-order acceptance clobbering newer edits.

---

## 3. Scope of Modifications

### A. Root Container & `.lcm` Decoupling (`D:\Git_Repositories`)
* Purged orphaned `D:\Workspace_Inventory`.
* Removed `.lcm/logs/`, `.lcm/archive/`, and `.lcm/scratch/` without junction bridges; redirected operational logs to `Workspace_Inventory/data/logs/lcm/` and scratch to `%TEMP%/lcm`.
* Created root NTFS hard links: `/.mcp.json` $\rightarrow$ `Workspace_AI/.agents/mcp_config.json`, and `/AGENTS.md` $\rightarrow$ `Workspace_AI/AGENTS.md`.
* Hardened shortname generator in `Update-ToolCatalog.ps1` using non-capturing prefix matching.
* Cleansed duplicate trampolines; restarted `LcmDesktopDaemon.ps1` on port 9876 logging to `Workspace_Inventory/data/logs/lcm-internal/`.

### B. Archives Isolation (`D:\Git_Repositories\Archives`)
* Created `#PermanentPurge.cmd` with typed `PERMANENT` confirmation gate and filter flags (`mcp`, `lcm`, `tools`, `all`).
* Removed all active tool references to `Archives\LCMpurges\tools`, redirecting retired tools to `Workspace_Inventory\data\retired_tools`.

### C. `SharedModules` Governance & Requirements (`SharedModules`)
* Restored `SharedModules` inclusion in `Show-Subsystems.ps1`.
* Updated `SharedModules/docs/Architecture.md` (v1.1.0) and `SharedModules/docs/Requirements.md` (v1.4.0) with draft status banners and Section 3 (`REQ-TOOL-001` through `REQ-TOOL-004`) defining satellite execution architecture and central tooling governance by `Workspace_Inventory`.

### D. `Workspace_Inventory` Requirements & Directional Lockstep (`Workspace_Inventory`)
* Updated `Workspace_Inventory/docs/Requirements.md`:
  * `REQ-WINV-003`: Added legacy backward-compatibility guard for missing `origin_repo`.
  * `REQ-WINV-004`: Refined wording to "all LCM-governed repositories".
  * `REQ-WINV-005`: Established directional lockstep push invariant with `SharedModules`.
  * Section 4 (`REQ-WINV-007` - `010`): Draft requirements hosting `ShowContracts`, `ShowInterfaces`, `ShowModules`, and `ShowAtoms`.

### E. Optimization Documentation & Governance Policy (`Workspace_AI`)
* Authored `Workspace_AI/docs/Optimizations/Catalog-of-Errors-and-Failure-Modes.md` analyzing 7 failure mode categories across sessions.
* Authored `Workspace_AI/docs/Optimizations/Data-Atoms-and-Design-Patterns.md` specifying 6 candidate Data Atoms for database design.
* Added `RULE-LCM-022` (Atomic Edit Consolidation & Editor Review Safety Invariant) to `ProposalReviewFlowPolicy.md` (v8.8.0) and `AGENTS.md`.
* Configured `"files.autoSave": "off"` in `.vscode/settings.json`.

---

## 4. Architectural Invariants
* **RULE-LCM-020**: Triple documentation files (`Specification.md`, `Implementation_Plan.md`, `Walkthrough.md`) in dedicated bundle directory `Workspace_Inventory/docs/Proposals/CRP-187-LCM-Decoupling-SharedModules-Governance-Review-Safety/`.
* **Zero Junctions for Volatile Logs**: Logs and scratch directories reside in dedicated inventory stores or `%TEMP%`, not in repository roots.
* **RULE-LCM-022**: Mandatory single-edit atomic consolidation per file per turn to prevent stacked IDE diffs.
