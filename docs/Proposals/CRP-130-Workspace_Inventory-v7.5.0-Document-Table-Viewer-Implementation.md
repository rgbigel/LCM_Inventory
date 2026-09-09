# Change Request Proposal: CRP-130
# Workspace Inventory Document Table Viewer Implementation

| Metadata Field | Value |
| :--- | :--- |
| **Proposal ID** | `CRP-130` |
| **Lifecycle State** | `OPEN` (Awaiting Operator Review & PROCEED Trigger) |
| **Origin Repository** | `Workspace_Inventory` |
| **Target Scope** | `WORKSPACE_INVENTORY_VIEWER.html` / `Docs` Modal & Viewer |
| **Author** | Rolf, Workspace_AI Governance |
| **Date** | 2026-09-09 |
| **Priority** | `Medium` |
| **Version Impact** | `v7.5.0` |
| **Extracted From** | Extracted from `CRP-103` (Section 3, Item 1 "Document Table Viewer") to separate inventory document table viewer implementation from interactive table display bundling (`BUNDLE-STD-DISPLAY-v7.5.0`). |

---

## 1. Executive Summary & Intent
Extract and formalize the implementation of the dedicated Document Table Viewer in `WORKSPACE_INVENTORY_VIEWER.html`.
Replaces the legacy unstructured document list with a full interactive Document Table (Columns: Checkbox, Document Name, Role, Version, Date, Review State, Actions `[Show, Print, Edit]`), with top-right `[⬅ Back]` navigation and persistent overflow scrollbars.

---

## 2. Normative Specification
1. Implement canonical tripartite document view in `WORKSPACE_INVENTORY_VIEWER.html`.
2. Map documents across repositories (`Architecture.md`, `Requirements.md`, `Implementation.md`, `Installation.md`).
3. Integrate row-level actions:
   - `[🔍 Show]`: Opens modal preview.
   - `[🖨️ Print]`: Dispatches formatted print atom.
   - `[✏️ Edit]`: Dispatches Notepad++ desktop editor.

---

## 3. Affected Components
- `Workspace_Inventory/docs/WORKSPACE_INVENTORY_VIEWER.html`
- `Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1`
