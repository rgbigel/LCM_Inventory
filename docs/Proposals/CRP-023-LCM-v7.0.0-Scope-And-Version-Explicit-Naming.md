# Change Request Proposal (CRP): Scope & Version-Explicit CRP Naming Standard

Module: LCM_Inventory/docs/Proposals/CRP-023-LCM-10.0.0-Scope-And-Version-Explicit-Naming.md  
Purpose: Mandates Scope and Version-Explicit naming conventions and header metadata for all Change Request Proposals.  
Target Scope: LCM / Governance  
Affected Version Range: 10.0.0+  
Impacted Repositories: [Root Container, LCM_Inventory, Child Repositories]  
Authors: Rolf, LCM_AI Engine  
Version: 10.0.0 (LCM Baseline: 10.0.0)
Status: PROPOSED / IMPLEMENTATION  
Date: 2026-10-13
Rule: RULE-LCM-007, RULE-DOC-001  

---

## 1. Executive Summary & Impact Classification

* **Proposal ID**: `CRP-023`
* **CR Reference**: `CR-2026-034` (Proposal #23)
* **Target Domain**: `LCM Governance & Change Management Architecture`
* **Impact Level**: `LOW` (Process, naming standard, and governance metadata enhancement).
* **Target Milestone**: `LCM 10.0.0`

---

## 2. Specification & Mandatory Naming Standard

### 2.1 Canonical Filename Structure
All future Change Request Proposals (CRPs) `MUST` follow the standardized 5-component naming convention:

```
CRP-YYYY-NNN-[Scope]-[Version]-[DescriptiveSlug].md
```

| Component | Format / Syntax | Allowed Values & Constraints |
|:---|:---|:---|
| `YYYY` | 4-digit Year | e.g. `2026` |
| `NNN` | 3-digit zero-padded number | e.g. `001`, `005`, `023` |
| `[Scope]` | Target repository or domain | • Single Repo: `LCM_AI`, `Installation_LCD`, `SystemConfiguration`, `HaSSD06`<br>• Workspace Platform / Core Rules: `LCM`<br>• Cross-Repository Bundle: `Multiple` |
| `[Version]` | Baseline or target version/range | • Major/Minor/Patch: `10.0.0`, `10.0.0`<br>• Range: `v6.0-v7.0`<br>• Unversioned / General: `vGeneral` |
| `[Slug]` | Kebab-case title | Short, descriptive title matching proposal intent |

### 2.2 Mandatory Header Metadata Block
Every CRP specification file `MUST` declare the canonical header metadata attributes:
- `Target Scope`: The exact affected subsystem, repository, or `LCM / Multi-Repo`.
- `Affected Version Range`: The baseline and target version horizon.
- `Impacted Repositories`: Explicit list of child repositories or workspace containers modified.

### 2.3 Retroactive Alignment of Prior CRPs
The existing CRP ledger is aligned with this convention:
- `CRP-023` $\to$ `CRP-023-LCM-10.0.0-Daemon-Enhancements.md`
- `CRP-023` $\to$ `CRP-023-LCM_AI-10.0.0-Gemini-Inbox-Watcher.md`
- `CRP-023` $\to$ `CRP-023-LCM-10.0.0-Review-Stop-Turn-Termination-Invariant.md`
- `CRP-023` $\to$ `CRP-023-LCM-10.0.0-Lightweight-Bug-Reporting.md`
- `CRP-023` $\to$ `CRP-023-LCM-10.0.0-Scope-And-Version-Explicit-Naming.md`

---

## 3. Governance Codification

Codified under `RULE-LCM-007` (Change Management Proposal Lifecycle) in [`.agents/rules/ProposalReviewFlowPolicy.md`](file:///d:/Git_Repositories/.agents/rules/ProposalReviewFlowPolicy.md).

