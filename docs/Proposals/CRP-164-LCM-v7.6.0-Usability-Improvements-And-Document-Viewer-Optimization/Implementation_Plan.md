# Implementation Plan: CRP-164

```yaml
CRP-ID: CRP-164
Title: Usability Improvements & Interactive Document Viewer Optimization
Scope: LCM Governance, CM Control Hub, Documentation Review Engine & Tools Catalog
Baseline-Version: v7.6.0
Author: Rolf, Workspace_AI Engine
Date: 2026-09-21
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: High
```

---

## 1. Technical Components & Proposed Implementation Steps

### Component 1: CM Control Hub Document Review Engine (`assets/CM_CONTROL_HUB.html`)
1. **Document Deduplication in `openRepoDocsReview()`**:
   - Filter `standardFiles` and `docsCache` iterations to ensure each canonical doc (e.g. `Architecture.md`) is pushed only once into `currentRepoDocsList`.
2. **High-Fidelity Preview & Paragraph Spacing**:
   - Update `formatMarkdown(text)` to normalize `\r\n` and `\n` into distinct paragraph `<p>` tags, formatted blockquotes, headings, code snippets, and lists.
   - Update `showDocPreviewByIndex(idx)` to render in a dedicated preview panel/modal cleanly.
3. **VS Code Editor Integration (`editInVSCode`)**:
   - Replace old `editInNotepad` with `editInVSCode(relPath)` that dispatches via `code -g <relPath>` or daemon without popup CMD windows.
   - Update batch open button text dynamically: "✏️ Open Selected in VS Code" (or "Open All in VS Code" if none checked).
   - Fix `showToast` definition and scope.
4. **Column Sizing & Word-Wrap Elimination**:
   - Update `#docViewerTable th` and `td` styles:
     - Review State: `width: 145px; min-width: 145px; white-space: nowrap;` (preventing `AUTHORITATIV_E` split).
     - Timestamp: `width: 120px;`.
5. **Button Cleanup & Pinning**:
   - Remove redundant bottom Print button (leaving only top "🖨️ Batch Print / PDF").
   - Remove redundant bottom Close button (relying on top "⬅️ Back").
   - Pin `#repoDocsModal` and `#appsModal` headers and filter bars with `position: sticky; top: 0; z-index: 10;`.
6. **Role Filter Fix**:
   - Update `extractDocMetadata` to classify `README.md` as role `"Overview"` / `"Readme"` and ensure dropdown filters correctly.

### Component 2: Tools Catalog, Defaults & Naming Architecture (`.lcm/config/` & `Workspace_Inventory/tools/`)
1. **Zero-Parameter Defaults**:
   - Update `Show-WorkspaceReadiness.ps1` to default `-TargetRepo` to current active focus repo (or `Workspace_AI`/all if none).
   - Update `Show-CmControlHub.ps1` and other tools to run with zero required parameters.
2. **Tool Naming & Deduplication**:
   - `Show-CrpDates.ps1` $\rightarrow$ Rename / alias to `Show-CRPs.ps1` producing clean table.
   - `Show-ToolIndex.ps1` $\rightarrow$ Consolidate with `Show-Tools.ps1`.
   - `Show-WorkspaceInventoryApp.ps1` $\rightarrow$ Rename to `Show-Inventory.ps1` and change audience to `User/Operational`.
3. **Tool Catalog Schema & Categorization**:
   - Add explicit `Dev/Internal` audience and categories in `tool_catalog.json`.

---

## 2. Verification Plan

1. **Unit & Integration Tests**:
   - Run Pester test suite (`ProposalManager.Tests.ps1`).
2. **Document Viewer UI Verification**:
   - Open `#repoDocsModal` for `.lcm`, verify exactly 3 tripartite rows (not 6).
   - Verify `AUTHORITATIVE` is on a single line.
   - Click preview and verify formatted paragraphs and headings.
   - Click "Open Selected in VS Code" and verify clean editor opening with 0 orphaned CMD windows.
3. **Zero-Parameter Tool Invocations**:
   - Run `Show-WorkspaceReadiness.ps1`, `Show-CRPs.ps1`, `Show-Inventory.ps1` with 0 parameters and verify expected default execution.
