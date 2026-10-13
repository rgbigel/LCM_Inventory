# Implementation Plan: CRP-187

## Metadata Header
* **Proposal ID**: `CRP-187`
* **Title**: LCM Runtime Decoupling, LCM_Shared Governance Integration, and Editor Review Safety Invariant
* **Bundle Directory**: `LCM_Inventory/docs/Proposals/CRP-187-LCM-Decoupling-LCM_Shared-Governance-Review-Safety/`

---

## 1. Affected Repositories & Components

| Repository | Component | Path | Nature of Change |
| :--- | :--- | :--- | :--- |
| **`D:\Git_Repositories`** (Root) | Operational Logs | `LCM_Inventory/data/logs/lcm/`, `LCM_Inventory/data/archives/`, `LCM_Inventory/scratch/` | Deleted and redirected to Inventory |
| **`D:\Git_Repositories`** (Root) | Configuration & Trampolines | `.gitignore`, `LCM_Inventory/config/tool_catalog.json`, `LCM_Inventory/Cmd/*.cmd` | Hard links, recursion fix, trampoline cleanup |
| **`D:\Git_Repositories`** (Root) | Tool Scripts & Modules | `LCM_Inventory/tools/...`, `LCM_Inventory/modules/...` | Redirected log paths to `LCM_Inventory/data/logs/lcm` |
| **`D:\Git_Repositories`** (Root) | Editor Settings | `.vscode/settings.json` | Set `files.autoSave: "off"` |
| **`D:\Git_Repositories\Archives`** | Junk Yard Utilities | `#PermanentPurge.cmd` | Filtered, confirmation-gated purge script |
| **`LCM_Shared`** | Architecture Spec | `docs/Architecture.md` | 10.0.0 satellite role and decoupled lifecycle draft |
| **`LCM_Shared`** | Requirements Spec | `docs/Requirements.md` | 10.0.0 Section 3 (`REQ-TOOL-*`) inspection tooling draft |
| **`LCM_Inventory`** | Governance Requirements | `docs/Requirements.md` | `REQ-WINV-003`, `004`, `005`, and Section 4 (`007`-`010`) |
| **`LCM_Inventory`** | Proposals Ledger | `data/proposals/proposals.json` | Register `CRP-187` as in-progress |
| **`LCM_AI`** | Optimization Specs | `docs/Optimizations/*.md` | Catalog of Errors and Data Atoms design docs |
| **`LCM_AI`** | Authoritative Policy Hub | `.agents/rules/ProposalReviewFlowPolicy.md`, `AGENTS.md` | `RULE-LCM-022` (Atomic Edit Consolidation) |

---

## 2. Step-by-Step Execution Sequence

1. **Step 1: Environmental Purge & Link Stabilization (Completed)**:
   - Purge `D:\LCM_Inventory`.
   - Establish NTFS hard links for `/.mcp.json` and `/AGENTS.md`.
2. **Step 2: Operational Telemetry Decoupling (Completed)**:
   - Relocate `LCM_Inventory/data/logs/lcm/` to `LCM_Inventory/data/logs/lcm/`.
   - Update 12 core `.lcm` scripts; purge `LCM_Inventory/logs`, `LCM_Inventory/archive`, `LCM_Inventory/scratch`.
   - Clean up shortname prefix recursion and duplicate trampolines.
3. **Step 3: Archives Isolation (Completed)**:
   - Implement `#PermanentPurge.cmd` with typed confirmation.
   - Decouple active tool references to `Archives\LCMpurges\tools`.
4. **Step 4: Subsystem & Requirements Alignment (Completed)**:
   - Include `LCM_Shared` in `Show-Subsystems.ps1`.
   - Synchronize tripartite specifications across `LCM_Shared` and `LCM_Inventory`.
5. **Step 5: Optimization Documentation & Policy Invariants (Completed)**:
   - Author `Catalog-of-Errors-and-Failure-Modes.md` and `Data-Atoms-and-Design-Patterns.md`.
   - Formulate and activate `RULE-LCM-022` in `ProposalReviewFlowPolicy.md` and `AGENTS.md`.
   - Configure `"files.autoSave": "off"` in `.vscode/settings.json`.
6. **Step 6: Beyond Compare Visual Review Gating (Active Target)**:
   - Execute Beyond Compare reviews across the 4 modified repositories (`LCM_Inventory`, `LCM_AI`, `LCM_Shared`, `D:\Git_Repositories`).
