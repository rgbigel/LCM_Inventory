---
title: "CRP-048: CM Control Hub Compact Prio Column (C/H/M/L/D), Filtering, Sorting & Persistence Engine"
crp_id: "CRP-048"
scope: "LCM_Inventory"
version: "10.2.0"
target_repos:
  - "LCM_Inventory"
type: "CRP"
priority: "High"
status: "In-Progress"
author: "Rolf, LCM_AI"
created_date: "2026-10-13 15:45:00"
---

# Change Request Proposal: CRP-048 – CM Control Hub Compact Prio Column (C/H/M/L/D) Engine

## 1. Context & Executive Summary
In the LCM Configuration Management Control Hub (`CM_CONTROL_HUB.html`), table column horizontal real estate is constrained. Proposal priority was previously unrepresented in the table, lacking visual indicators, header filtering, and sorting capabilities. Furthermore, priority values in `proposals.json` were sparse and unstructured.

This Change Request Proposal establishes a compact, space-conserving **`Prio`** column using standardized single-letter priority codes, introduces interactive header filtering and sorting, and provides full persistence across the UI, REST daemon, and PowerShell backend.

---

## 2. Priority Taxonomy & Semantics
Priority is strictly defined using a 5-tier single-letter taxonomy:

| Code | Meaning | Semantic Description | Display Tone / Styling | Default Assignment |
|:---:|:---|:---|:---|:---|
| **`C`** | **Critical** | Severe blocker, transport outage, data corruption hazard. | Bold Red (`#f85149`) | Urgent BUGs |
| **`H`** | **High** | High-impact feature, broken UI element, blocking dependency. | Amber / Orange (`#d29922`) | Standard BUGs, High CRPs |
| **`M`** | **Medium** | Normal planned work, routine feature, standard CRP. | Blue (`#58a6ff`) | Default for all standard proposals |
| **`L`** | **Low** | Minor convenience, low-urgency polish, non-blocking refactor. | Slate Muted (`#8b949e`) | Polish items |
| **`D`** | **Designated for later** | Parked idea, future exploration, delayed backlog. | Dim Gray (`#6e7681`) | Deferred / backlog items |

---

## 3. Architectural Specifications

### 3.1 Table Display (`CM_CONTROL_HUB.html`)
- **Header**: Compact header named `Prio` with filter dropdown (`All`, `C`, `H`, `M`, `L`, `D`) and click-to-sort toggle (`Prio ⬍`).
- **Row Cell**: Compact, color-coded interactive `<select>` element (width ~46px–50px) allowing 1-click priority modification with hover tooltips (`C (Critical)`, etc.).
- **Live Persistence**: Selecting a new priority in the dropdown immediately dispatches a REST command to the Desktop Daemon (`127.0.0.1:9876/execute`) calling `Invoke-ProposalAction.ps1 -Action priority -TargetExpression <id> -Priority <val>`.

### 3.2 Sorting & Filtering Engine
- Header dropdown filters the visible proposals to matching priority codes.
- Clicking the `Prio` column header cycles between:
  - **Ascending (`C ➔ H ➔ M ➔ L ➔ D`)**: Highest urgency first.
  - **Descending (`D ➔ L ➔ M ➔ H ➔ C`)**: Lowest urgency first.
  - Reset to default ID order.

### 3.3 Interactive Console Commands
- Supports `prio #<id> <C|H|M|L|D>` (e.g. `prio #78 H` or `priority #79 C`).
- Supports batch priority assignment: `prio 70-75 M`.

### 3.4 PowerShell & Ledger Support
- `ProposalManager.psm1`: Add `Set-WorkspaceProposalPriority -Id <int> -Priority <string>` validating against `[ValidateSet('C', 'H', 'M', 'L', 'D')]`.
- `Invoke-ProposalAction.ps1`: Add `-Action priority -Priority <string>`.
- One-time migration/backfill of existing proposals in `proposals.json`: Existing `"High"` maps to `H`, `"MEDIUM"` to `M`, `BUG`s without priority map to `H`, and unassigned items map to `M`.

---

## 4. Verification Plan
1. Schema and ledger backfill validation in `proposals.json`.
2. AST syntax check of `CM_CONTROL_HUB.html` and PowerShell module checks.
3. Verification of column display, filtering, two-way sorting, and dropdown persistence.

