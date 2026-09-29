# Implementation Plan: CRP-187

## Metadata Header
* **Proposal ID**: `CRP-187`
* **Title**: LCM Runtime Decoupling, SharedModules Governance Integration, and Editor Review Safety Invariant
* **Bundle Directory**: `Workspace_Inventory/docs/Proposals/CRP-187-LCM-Decoupling-SharedModules-Governance-Review-Safety/`

---

## 1. Affected Repositories & Components

| Repository | Component | Path | Nature of Change |
| :--- | :--- | :--- | :--- |
| **`D:\Git_Repositories`** (Root) | Operational Logs | `.lcm/logs/`, `.lcm/archive/`, `.lcm/scratch/` | Deleted and redirected to Inventory |
| **`D:\Git_Repositories`** (Root) | Configuration & Trampolines | `.gitignore`, `.lcm/config/tool_catalog.json`, `.lcm/Cmd/*.cmd` | Hard links, recursion fix, trampoline cleanup |
| **`D:\Git_Repositories`** (Root) | Tool Scripts & Modules | `.lcm/tools/...`, `.lcm/modules/...` | Redirected log paths to `Workspace_Inventory/data/logs/lcm` |
| **`D:\Git_Repositories`** (Root) | Editor Settings | `.vscode/settings.json` | Set `files.autoSave: "off"` |
| **`D:\Git_Repositories\Archives`** | Junk Yard Utilities | `#PermanentPurge.cmd` | Filtered, confirmation-gated purge script |
| **`SharedModules`** | Architecture Spec | `docs/Architecture.md` | v1.1.0 satellite role and decoupled lifecycle draft |
| **`SharedModules`** | Requirements Spec | `docs/Requirements.md` | v1.4.0 Section 3 (`REQ-TOOL-*`) inspection tooling draft |
| **`Workspace_Inventory`** | Governance Requirements | `docs/Requirements.md` | `REQ-WINV-003`, `004`, `005`, and Section 4 (`007`-`010`) |
| **`Workspace_Inventory`** | Proposals Ledger | `data/proposals/proposals.json` | Register `CRP-187` as in-progress |
| **`Workspace_AI`** | Optimization Specs | `docs/Optimizations/*.md` | Catalog of Errors and Data Atoms design docs |
| **`Workspace_AI`** | Authoritative Policy Hub | `.agents/rules/ProposalReviewFlowPolicy.md`, `AGENTS.md` | `RULE-LCM-022` (Atomic Edit Consolidation) |

---

## 2. Step-by-Step Execution Sequence

1. **Step 1: Environmental Purge & Link Stabilization (Completed)**:
   - Purge `D:\Workspace_Inventory`.
   - Establish NTFS hard links for `/.mcp.json` and `/AGENTS.md`.
2. **Step 2: Operational Telemetry Decoupling (Completed)**:
   - Relocate `.lcm/logs/` to `Workspace_Inventory/data/logs/lcm/`.
   - Update 12 core `.lcm` scripts; purge `.lcm/logs`, `.lcm/archive`, `.lcm/scratch`.
   - Clean up shortname prefix recursion and duplicate trampolines.
3. **Step 3: Archives Isolation (Completed)**:
   - Implement `#PermanentPurge.cmd` with typed confirmation.
   - Decouple active tool references to `Archives\LCMpurges\tools`.
4. **Step 4: Subsystem & Requirements Alignment (Completed)**:
   - Include `SharedModules` in `Show-Subsystems.ps1`.
   - Synchronize tripartite specifications across `SharedModules` and `Workspace_Inventory`.
5. **Step 5: Optimization Documentation & Policy Invariants (Completed)**:
   - Author `Catalog-of-Errors-and-Failure-Modes.md` and `Data-Atoms-and-Design-Patterns.md`.
   - Formulate and activate `RULE-LCM-022` in `ProposalReviewFlowPolicy.md` and `AGENTS.md`.
   - Configure `"files.autoSave": "off"` in `.vscode/settings.json`.
6. **Step 6: Beyond Compare Visual Review Gating (Active Target)**:
   - Execute Beyond Compare reviews across the 4 modified repositories (`Workspace_Inventory`, `Workspace_AI`, `SharedModules`, `D:\Git_Repositories`).
