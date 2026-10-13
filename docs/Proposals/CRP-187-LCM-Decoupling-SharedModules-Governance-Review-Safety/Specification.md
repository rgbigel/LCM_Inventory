# Change Request Proposal: CRP-187

## Metadata Header
* **Proposal ID**: `CRP-187`
* **Title**: LCM Runtime Decoupling, LCM_Shared Governance Integration, and Editor Review Safety Invariant
* **Author**: Rolf, Antigravity AI Assistant
* **Date**: 2026-10-13
* **Status**: In-Progress
* **Target Repositories**: `D:\Git_Repositories` (Root), `LCM_Inventory`, `LCM_AI`, `LCM_Shared`
* **App Context**: `A7` (Proposal Management / LCM Hub) & `A1` (Subsystems & Governance Engine)
* **Lifecycle State**: In-Progress (DOIT Mode activated)

---

## 1. Executive Summary & Intent
This comprehensive proposal formalizes the structural decoupling of operational runtime data from the `.lcm` repository container, decouples legacy archives from active workspace tooling, restores `LCM_Shared` to the authoritative LCM subsystem matrix under draft governance by `LCM_Inventory`, synthesizes session failure modes and Data Atoms into formal engineering documentation, and establishes `RULE-LCM-022` to eliminate multi-review editor buffer collisions.

---

## 2. Problem Statement
1. **Runtime Namespace Sprawl in `.lcm`**:
   - Runtime operations logged directly to `LCM_Inventory/data/logs/lcm/` and `LCM_Inventory/scratch/`, causing search slowdowns and coupling volatile telemetry to the core LCM tooling codebase.
   - An orphaned, obsolete directory `D:\LCM_Inventory` existed alongside the governed repository.
2. **Ambiguous Archive Boundaries**:
   - `D:\Git_Repositories\Archives` was loosely referenced in active tools (`DaemonActionController.ps1`, `lcm-tool-explorer.js`, `LcmToolCatalog.psm1`) as if it were a functional subsystem, violating the principle of an isolated junk yard.
3. **Exclusion of `LCM_Shared` from Subsystem Dashboards**:
   - `Show-Subsystems.ps1` explicitly filtered out `LCM_Shared`, obscuring a governed, version-controlled library repository from workspace visibility.
   - Lack of documented inspection tool requirements (`ShowContracts`, `ShowInterfaces`, `ShowModules`, `ShowAtoms`) and system of record versioning boundaries.
4. **Tool Catalog ShortName Collision & Recursion**:
   - Repeated regex prefixing in `Update-ToolCatalog.ps1` produced runaway prefixes (`LCMLCMLCM...ClearBCReviewTemp.cmd`).
5. **IDE Multi-Review Editor Collisions**:
   - Rapid back-to-back edits on open files created stacked, ambiguous "Accept" diff decorations in the IDE editor, creating risks of out-of-order acceptance clobbering newer edits.

---

## 3. Scope of Modifications

### A. Root Container & `.lcm` Decoupling (`D:\Git_Repositories`)
* Purged orphaned `D:\LCM_Inventory`.
* Removed `LCM_Inventory/data/logs/lcm/`, `LCM_Inventory/data/archives/`, and `LCM_Inventory/scratch/` without junction bridges; redirected operational logs to `LCM_Inventory/data/logs/lcm/` and scratch to `%TEMP%/lcm`.
* Created root NTFS hard links: `/.mcp.json` $\rightarrow$ `LCM_AI/.agents/mcp_config.json`, and `/AGENTS.md` $\rightarrow$ `LCM_AI/AGENTS.md`.
* Hardened shortname generator in `Update-ToolCatalog.ps1` using non-capturing prefix matching.
* Cleansed duplicate trampolines; restarted `LcmDesktopDaemon.ps1` on port 9876 logging to `LCM_Inventory/data/logs/lcm-internal/`.

### B. Archives Isolation (`D:\Git_Repositories\Archives`)
* Created `#PermanentPurge.cmd` with typed `PERMANENT` confirmation gate and filter flags (`mcp`, `lcm`, `tools`, `all`).
* Removed all active tool references to `Archives\LCMpurges\tools`, redirecting retired tools to `LCM_Inventory\data\retired_tools`.

### C. `LCM_Shared` Governance & Requirements (`LCM_Shared`)
* Restored `LCM_Shared` inclusion in `Show-Subsystems.ps1`.
* Updated `LCM_Shared/docs/Architecture.md` (10.0.0) and `LCM_Shared/docs/Requirements.md` (10.0.0) with draft status banners and Section 3 (`REQ-TOOL-001` through `REQ-TOOL-004`) defining satellite execution architecture and central tooling governance by `LCM_Inventory`.

### D. `LCM_Inventory` Requirements & Directional Lockstep (`LCM_Inventory`)
* Updated `LCM_Inventory/docs/Requirements.md`:
  * `REQ-WINV-003`: Added legacy backward-compatibility guard for missing `origin_repo`.
  * `REQ-WINV-004`: Refined wording to "all LCM-governed repositories".
  * `REQ-WINV-005`: Established directional lockstep push invariant with `LCM_Shared`.
  * Section 4 (`REQ-WINV-007` - `010`): Draft requirements hosting `ShowContracts`, `ShowInterfaces`, `ShowModules`, and `ShowAtoms`.

### E. Optimization Documentation & Governance Policy (`LCM_AI`)
* Authored `LCM_AI/docs/Optimizations/Catalog-of-Errors-and-Failure-Modes.md` analyzing 7 failure mode categories across sessions.
* Authored `LCM_AI/docs/Optimizations/Data-Atoms-and-Design-Patterns.md` specifying 6 candidate Data Atoms for database design.
* Added `RULE-LCM-022` (Atomic Edit Consolidation & Editor Review Safety Invariant) to `ProposalReviewFlowPolicy.md` (10.0.0) and `AGENTS.md`.
* Configured `"files.autoSave": "off"` in `.vscode/settings.json`.

---

## 4. Architectural Invariants
* **RULE-LCM-020**: Triple documentation files (`Specification.md`, `Implementation_Plan.md`, `Walkthrough.md`) in dedicated bundle directory `LCM_Inventory/docs/Proposals/CRP-187-LCM-Decoupling-LCM_Shared-Governance-Review-Safety/`.
* **Zero Junctions for Volatile Logs**: Logs and scratch directories reside in dedicated inventory stores or `%TEMP%`, not in repository roots.
* **RULE-LCM-022**: Mandatory single-edit atomic consolidation per file per turn to prevent stacked IDE diffs.
