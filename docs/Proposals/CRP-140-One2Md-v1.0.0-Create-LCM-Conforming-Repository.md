---
Proposal-ID: CRP-140
CR-ID: CRP-140
Scope: One2Md
Version: v1.0.0
Affected-Repos: [One2Md, LCM_Inventory]
Severity: Low
Status: COMPLETED
Date: 2026-09-12
Author: Rolf / Antigravity AI Engine
Target Scope: One2Md/
Affected Version Range: v1.0.0
Impacted Repositories: [One2Md, LCM_Inventory]
---

# Change Request Proposal: CRP-140
# Create LCM-Conforming Repository "One2Md" with Enhanced Wrapper Script and Baseline v1.0.0

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-140` |
| **Lifecycle State** | `COMPLETED` |
| **Origin Repository** | `One2Md` |
| **Target Scope** | `One2Md/` |
| **Author** | Rolf / Antigravity AI Engine |
| **Date** | 2026-09-12 |
| **Priority** | `Medium` |
| **Version Impact** | `v1.0.0` |

---

## 1. Executive Summary & Rationale
The operator requested the creation of a new, LCM-conforming tool repository named **One2Md** at `D:\Git_Repositories\One2Md`.
This repository absorbs an initial interactive PowerShell prototype script designed to interface with the Python `one-to-md` CLI utility (`D:\Tools\Python314\Scripts\one-to-md.exe`), which converts Microsoft OneNote desktop notebooks into Markdown trees with extracted image and attachment assets.

The prototype requires improvements to conform with the workspace's authoritative Lifecycle Model governance:
1. **PowerShell Standards Compliance**:
   - `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` (`RULE-PS-005`).
   - Standard DOX file metadata header (`RULE-PS-008`).
   - CLI `-h` / `-Help` parameter support (`RULE-PS-010`).
   - Safe array subexpression wrapping `@(...)` under StrictMode (`RULE-PS-001`).
   - Colon-safe string interpolation (`RULE-PS-003` / `RULE-PS-015`).
   - Prohibition of bare inline `(if ...)` statements (`RULE-PS-012`).
   - Structured audit logging (`RULE-PS-009`).
2. **Dynamic Discovery & Preflight Checks**:
   - Dynamic resolution of `one-to-md.exe` across PATH and standard Python directories.
   - Preflight detection of the running OneNote desktop process (`ONENOTE.EXE`).
   - Dual execution modes: interactive wizard prompting and headless CLI execution.
3. **Tripartite Documentation & Runbooks**:
   - Tripartite specifications (`Architecture.md`, `Requirements.md`, `Implementation.md`) per `RULE-DOC-001`.
   - Mandatory 7-phase procedural lifecycle installation runbook (`install/Installation.md`) per `RULE-DOC-004`.
4. **Quality Gates & Governance**:
   - Pester v5 test suite and `Test-RepoReadiness.ps1` quality gate.
   - NTFS junction linking `.agents/rules` to `LCM_Inventory\.agents\rules`.

---

## 2. Proposed Architecture & File Inventory
- `Source/One2Md.ps1`: Enhanced interactive/CLI wrapper engine.
- `Source/One2Md.cmd`: Portable CMD launcher wrapper.
- `README.md`: Executive repository overview and navigation index.
- `docs/Architecture.md`: System topology, user mental model, and execution flows.
- `docs/Requirements.md`: Technical prerequisites, normative invariants, and persistence schema.
- `docs/Implementation.md`: Code inventory, parameter signatures, and test traceability.
- `docs/Changelog.md`: Baseline release history.
- `install/Installation.md`: 7-phase installation runbook.
- `install/Install-One2Md.ps1`: Deployment automation to `D:\OneDrive\cmd\`.
- `tests/One2Md.Tests.ps1`: Pester v5 test suite.
- `tools/Test-RepoReadiness.ps1`: Local repository readiness quality gate.

---

## 3. Compliance & Governance Invariants
- **RULE-DOC-001 / 002 / 003**: Tripartite documentation and DOX headers.
- **RULE-DOC-004**: Universal `install/Installation.md` runbook standard.
- **RULE-PS-001 - 015**: Complete PowerShell coding standards adherence.
- **RULE-REV-001 / 007**: Quality gate verification and version alignment (`v1.0.0`).
