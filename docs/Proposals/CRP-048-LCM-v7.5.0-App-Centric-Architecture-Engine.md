# CRP-048: App-Centric Architectural Synthesis, Active Context Engine & High-Order Decomposition Tooling

Module: docs/Proposals/CRP-048-LCM-10.0.0-App-Centric-Architecture-Engine.md  
Purpose: Formalizes the App-Centric Architecture Taxonomy (App: #), the Active Context Engine (Workon: A#), and cross-App problem governance in the LCM framework.  
Path: LCM_Inventory/docs/Proposals/CRP-048-LCM-10.0.0-App-Centric-Architecture-Engine.md  
Authors: Rolf, LCM_AI Engine  
Version: 10.2.0
Status: Approved Proposal  
Date: 2026-10-13

---

## 1. Executive Summary & Problem Statement
Prior architectural governance mandated tripartite specifications (Architecture, Requirements, Implementation) under `RULE-DOC-001`, but lacked a formal modular decomposition standard for scaling repositories. As systems grew, monolithic documentation files created high cognitive load and excessive LLM context consumption during automated code generation. Furthermore, architectural design discussions conducted with AI assistants were at risk of being lost upon session termination.

CRP-048 formalizes the **App-Centric Architecture Taxonomy (`App: #`)**, an **Active Feature Context Engine (`Workon: A#`)**, and **Automated Tripartite Synthesis upon `ACCEPT`**.

---

## 2. Core Architectural Pillars

### Pillar A: Conclusive State Capture on ACCEPT (Absorbing Original AADD)
- Technical and design decisions reached during AI-human discussions `MUST NOT` be lost upon session conclusion.
- The `ACCEPT <id>` / `complete <id>` command acts as the authoritative lifecycle trigger.
- On `ACCEPT`, the conclusive architecture decisions, technical constraints, and code manifests are deterministically synthesized into the repository's tripartite documentation under the designated `App: #` section.

### Pillar B: The "App:" Incremental Syntax & Structure
- **Format**: `App: <Number> - <Title>` (e.g. `App: 1 - CM Interactive Control Hub`).
- **Creation Operator**: `App: <Title>` automatically calculates the next available integer (e.g., `App: 3 - Realtime Log Streamer`) and scaffolds the section across `Architecture.md`, `Requirements.md`, and `Implementation.md`.
- **Zero-Bracket Invariant**: Uses plain hyphenated text (`App: 1 - Title` / `A1`), eliminating bracket overhead.
- **Optional Default**: Repositories not requiring modular slicing remain standard un-prefixed tripartite specs.

### Pillar C: Active Context Engine (`Workon:`)
- **`Workon: A1` (or `Workon: 1`)**: Sets the active working focus in `.agents/ACTIVE_SESSION.md`. All subsequent proposal intake (`crp: ...`, `bug: ...`) automatically inherits `app_id: "App: 1"`.
- **`Workon: Architecture` (or `Workon: Base`)**: Shifts focus to foundational primitives and root architecture.

### Pillar D: 3-Tier Code Mapping & Machine-Readable Catalog (`apps.json`)
1. **`Implementation.md`**: Declares the **Constituent Manifest Table** for each `App: #` listing paths, roles, and exported entrypoints.
2. **Code Headers**: Scripts declare `App: App: # - <Title>` in their standard DOX block.
3. **`data/catalog/apps.json`**: Authoritative, machine-readable registry compiled automatically by `Sync-LcmAppCatalog.ps1`.

### Pillar E: High-Order Lifecycle Operators
- **`Split-LcmArchitectureToApps.ps1`**: Decomposes monolithic tripartite specs into modular `App: #` slices.
- **`Merge-RepositoriesToApps.ps1`**: Merges external child repositories into a target umbrella repo as distinct `App: #` slices.

### Pillar F: Inter-App Contract Governance (The "Glue")
- Inter-App communication is strictly prohibited from reaching into private internal functions or state.
- All inter-App interactions are governed by formal, registered **Interface Contracts** (Cmdlet Exports, Typed Schemas/DTOs, REST Endpoints, Event Broadcasts) cataloged in `LCM_Inventory/data/catalog/contracts.json`.
- AST drift probers audit all calls and flag unsanctioned cross-App coupling.

### Pillar G: The Atomic Assembly Paradigm (The Ultimate Goal)
- Software construction transforms from bespoke, handcrafted coding into **Deterministic Atomic Assembly**:
  1. **Level 0 (Elementary Atoms)**: Pure single-purpose building blocks (parsers, renderers, tokens).
  2. **Level 1 (High-Level Assemblies)**: Functional modules composed of atoms (`ProposalStore`, `DaemonController`).
  3. **Level 2 (Apps)**: Macro capabilities composed of assemblies (`App: 1 - Control Hub`, `App: 2 - Governance`).
  4. **Level 3 (Repository Ecosystem)**: Coordinated Apps bound by interface contracts.
- **Operator Payoff**: Rapid, zero-hallucination AI code synthesis by assembling pre-verified atomic particles directly from `Implementation.md` blueprints.

---

## 3. Concluded Alternatives Matrix

| Architectural Option | Alternative Evaluated | Final Decision | Rationale & Trade-Off |
| :--- | :--- | :--- | :--- |
| **Discussion Capture** | Raw Discussion Logging (AADD transcripts / meeting notes) | **Feature/App-Driven Synthesis** | *Rejected*: Raw transcripts accumulate noise, lack cohesion, and decay rapidly. *Adopted*: Conclusive discussions synthesize directly into named `App: #` sections upon `ACCEPT`. |
| **Directory Structure** | Subdirectory Sprawl (`docs/App1/`, `docs/App2/`) | **Flat In-Document Section Slices** | *Rejected*: Directory sprawl fragments the clean single-entrypoint tripartite standard (`RULE-DOC-001`). *Adopted*: In-document `App: #` headers inside tripartite specs; folders reserved strictly for autonomous subsystems. |
| **Prefix Syntax** | Angle/Square Brackets (`<App: 1>`, `[App: 1]`) | **Hyphenated Colon Format (`App: 1 - <Title>`)** | *Rejected*: Brackets add typing friction in CLI/markdown. *Adopted*: Clean plain-text `App: 1 - <Title>` and shorthand `A1`. |
| **Domain Nomenclature** | Commercial "Feature" naming (`Feat1`) | **Neutral "App" Slice Taxonomy (`App: 1`)** | *Rejected*: "Feature" carries end-user product bias unsuitable for low-level tooling/governance. *Adopted*: Versatile `App` (Application Slice / Architectural Increment). |

---

## 4. Governance Policy Updates
1. **`DocumentationStandardsPolicy.md` (`RULE-DOC-007`)**:
   - Formalizes the `App: #` modular tripartite standard and constituent manifest requirements.
2. **`ProposalReviewFlowPolicy.md` (`RULE-LCM-019`)**:
   - Mandates active `Workon:` context inheritance during intake and automated tripartite synthesis upon `ACCEPT`.

---

## 5. Implementation Phasing
- **Phase 1 (Documentation & Architecture Sync)**: Codify Section 10 in `LCM_AI/docs/Architecture.md` (Complete).
- **Phase 2 (Governance & Policy Sync)**: Update `DocumentationStandardsPolicy.md` and `ProposalReviewFlowPolicy.md`.
- **Phase 3 (Core CLI & Context Engine)**: Implement `Workon:`, `App:`, `apps`, and `Sync-LcmAppCatalog.ps1` in `ProposalManager.psm1`.
- **Phase 4 (CM Control Hub Display Integration)**: Add Active App badge, App Reference Modal/Drawer, and table filtering in `CM_CONTROL_HUB.html`.
- **Phase 5 (High-Order Operators)**: Implement `Split-LcmArchitectureToApps.ps1` and `Merge-RepositoriesToApps.ps1`.
