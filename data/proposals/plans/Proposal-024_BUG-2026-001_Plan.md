# Plan: Proposal #24 (BUG-2026-001) - Fix .NET Regex String Interpolation Backreference Corruption in CM Control Hub HTML Data Injector

**Proposal ID**: #24  
**Change Request / Bug ID**: `BUG-2026-001`  
**Bundle ID**: `CRP-2026-006`  
**Origin Repository**: `Workspace_Inventory`  
**Author**: Rolf  
**Status**: Completed (Accepted)  
**Date**: 2026-08-30  

---

## 1. Problem Statement & Root Cause

When rendering the CM Control Hub web dashboard via `Show-CmControlHub.ps1`, the script injected the pre-loaded offline documents cache dictionary (`RAW_DOCS_CACHE`) into `CM_CONTROL_HUB.html` using `.NET Regex.Replace($htmlContent, pattern, $injectedBlock)`.

Because the cached PowerShell code files contained dollar-sign variables (`$target`, `$_`, `$Matches[1]`), the .NET regex engine interpreted those characters as regex backreference capture groups (`$1`, `$&`). This corrupted the `<script>` opening tag right after `<div id="toast">Action Executed Successfully</div>`, spilling hundreds of lines of raw JSON/PowerShell code directly into the browser DOM as visible text.

---

## 2. Proposed & Executed Changes

1. **Replace Regex with Literal String Substitution**:
   * Replace `.NET Regex.Replace` with byte-exact literal string `.Replace('/*__INJECTED_DATA_PLACEHOLDER__*/', $injectedBlock)`.
   * Literal string replacement treats all characters literally, preventing any special interpretation of `$` variables in injected script content.
2. **Template Deduplication**:
   * Removed duplicate function blocks from `Workspace_Inventory/docs/CM_CONTROL_HUB.html`.
3. **Validation**:
   * Re-rendered `Workspace_Inventory/scratch/CM_CONTROL_HUB.html` and verified valid HTML and script tags.

---

## 3. Verification Plan

* **Automated Quality Gate**: `pwsh -File Workspace_AI/tools/Test-WorkspaceReadiness.ps1`
* **Visual & DOM Verification**: Inspect generated `scratch/CM_CONTROL_HUB.html` to confirm clean HTML parsing.
