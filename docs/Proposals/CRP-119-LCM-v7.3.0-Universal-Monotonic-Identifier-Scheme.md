# Change Request Proposal: CRP-119
# Universal Monotonic CRP/BUG-nnn Identifier Naming Scheme

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-119` |
| **Lifecycle State** | `COMPLETED` (Implemented & Verified) |
| **Origin Repository** | `LCM` / Configuration Management & Governance |
| **Target Scope** | Proposal Lifecycle & Naming Standard (`proposals.json`, `Workspace_Inventory/docs/Proposals/`, `Show-CmControlHub.ps1`, `Invoke-BeyondCompareReview.ps1`, `Invoke-ProposalAction.ps1`, `ProposalManager.psm1`) |
| **Author** | Rolf, Workspace_AI |
| **Date** | 2026-09-08 |
| **Version Impact** | `v7.3.0` |
| **Predecessors** | `CRP-107`, `CRP-116`, `CRP-117`, `CRP-118` |

---

## 1. Executive Summary & Objective

Currently, proposals in the LCM governance plane suffer from a **dual-numbering identity divergence**:
- The **Ledger ID**: Sequential integer `1..118` (used in `Show-CmControlHub`, web console, URL anchors, and transition histories).
- The **Annual Code**: Annual sequence `CRP-2026-001` through `CRP-2026-032` (used in filenames in `docs/Proposals/`, BRC review folders, and Git commit tags).

This causes friction, requiring lookup tables to correlate e.g. `Proposal #118` with `CRP-2026-032`.

### The Approved Decision
Replace the dual-numbering system with a **single canonical identifier in the form `CRP-nnn` or `BUG-nnn`**:
1. **Universal Monotonic Sequence**: The number `nnn` is strictly the proposal's unique integer ID in `proposals.json` (zero-padded to 3 digits: `001`, `002`, ... `118`, `119`, scaling past `999`).
2. **Shared Sequence Counter**:
   - Enhancement/feature proposals use the prefix **`CRP-nnn`** (e.g. `CRP-118`, `CRP-119`).
   - Defect/bug fix proposals use the prefix **`BUG-nnn`** (e.g. `BUG-024`, `BUG-072`), drawing from the exact same numerical sequence.
   - This eliminates the need for an additional `type: "bug" | "feature"` column or database field.
3. **1:1 Direct Filename Parity**: Specification documents in `docs/Proposals/` match the identifier directly:
   `Workspace_Inventory/docs/Proposals/CRP-nnn-LCM-v7.3.0-<Slug>.md` or `BUG-nnn-LCM-v7.3.0-<Slug>.md`.

---

## 2. Architecture & Implementation Scope

### 2.1 Identifier Syntax Specification
The canonical regex pattern across all tools, scripts, and validators is standardized to:
```regex
^(?:CRP|BUG)-(?<id>\d{3,})$
```
- **Padding**: Minimum 3 digits (e.g. `001` to `999`), expanding to 4 digits (`1000+`) without reset.
- **Uniqueness**: Sequence numbers are strictly unique across both `CRP` and `BUG` prefixes. If ID `120` is a bug, it is `BUG-120`; proposal `121` will be `CRP-121`. There is never both a `CRP-120` and a `BUG-120`.

### 2.2 Proposals Ledger Normalization (`proposals.json`)
For every proposal record:
- `id`: Numeric integer (e.g. `119`).
- `crp_id`: Canonical formatted identifier (e.g. `"CRP-119"` or `"BUG-024"`).
- `cr_id`: Deprecated or set identical to `crp_id` for backward compatibility.
- `plan_path`: Normalized to the new canonical filename format.

### 2.3 Automated File Migration (`Migrate-CrpNamingScheme.ps1`)
Provide an automated, idempotent migration tool:
```powershell
pwsh Workspace_Inventory/tools/Migrate-CrpNamingScheme.ps1 [-WhatIf] [-Force]
```
1. **Catalog & Ledger Mapping**:
   - Maps each existing file in `Workspace_Inventory/docs/Proposals/` to its proposal `id` in `proposals.json`.
2. **File Renaming**:
   - Renames legacy files matching `CRP-2026-yyy-*` or `BUG-2026-yyy-*` to `CRP-nnn-*` or `BUG-nnn-*` using `git mv` to preserve Git blame and history.
3. **Ledger Update**:
   - Updates `plan_path` and `crp_id` fields in `proposals.json` to reflect the renamed paths.
4. **Tooling Alignment**:
   - Audits and updates regexes in:
     - `Show-CmControlHub.ps1` (`CM_CONTROL_HUB.html`)
     - `Invoke-BeyondCompareReview.ps1`
     - `Invoke-ProposalAction.ps1`
     - `ProposalManager.psm1`
     - `lcm-tool-explorer.js`

---

## 3. Invariant & Governance Verification Plan

| Invariant / Check | Expected Behavior | Verification Method |
| :--- | :--- | :--- |
| **Deterministic 1:1 Identity** | Proposal `#119` corresponds strictly to `CRP-119` in ledger, file name, and console. | Inspect `proposals.json` and file system. |
| **Shared Sequence Integrity** | No overlapping numbers between `CRP-nnn` and `BUG-nnn`. | Automated ledger uniqueness test. |
| **Git History Preservation** | Renaming legacy proposal documents uses `git mv` to preserve lineage. | `git log --follow` on renamed proposal files. |
| **Tooling Regex Compatibility** | `Show-CmControlHub` filters, search, and actions correctly parse `CRP-nnn` and `BUG-nnn`. | Launch Control Hub and test search and table rendering. |

---

## 4. Current State & Promotion Notice

> [!NOTE]
> This proposal is registered in **`OPEN`** state. Implementation is approved per operator directive and scheduled for execution.
