---
Bug-ID: BUG-024
Scope: LCM_Inventory
Version: v7.1.0
Affected-Repos: [LCM_Inventory]
Severity: High
Status: Completed
Date: 2026-08-30
Author: Rolf
Root-Cause: .NET Regex.Replace interpreted PowerShell dollar-sign variables as regex capture groups during HTML data injection, corrupting script tags.
---

# BUG-024: Fix .NET Regex String Interpolation Backreference Corruption in CM Control Hub HTML Data Injector

## 1. Defect Description
When generating `LCM_Inventory/scratch/CM_CONTROL_HUB.html` via `Show-CmControlHub.ps1`, the script injected pre-loaded cache dictionaries (`RAW_DOCS_CACHE`) into the HTML template using `[System.Text.RegularExpressions.Regex]::Replace($htmlContent, pattern, $injectedBlock)`.

Because PowerShell code files in the documents cache contained dollar signs (`$target`, `$_`, `$Matches[1]`), the .NET regex engine interpreted them as **regex backreference substitution groups** (`$1`, `$&`), breaking the `<script>` opening tag right after `<div id="toast">Action Executed Successfully</div>` and dumping hundreds of lines of raw JSON/code directly into the browser DOM as visible text.

---

## 2. Root Cause Analysis
* `.NET Regex.Replace(input, pattern, replacement)` treats `$` in the replacement string as special substitution tokens.
* When injected data contains arbitrary source code (specifically PowerShell scripts), regex replacement is inherently unsafe.

---

## 3. Corrective Action & Implementation
1. **Deterministic Literal String Substitution**:
   * Replaced `Regex.Replace` with `.Replace('/*__INJECTED_DATA_PLACEHOLDER__*/', $injectedBlock)`.
   * Literal string replacement treats all characters literally, preventing any backreference evaluation.
2. **Template Hygiene**:
   * Removed duplicate function blocks from `LCM_Inventory/docs/CM_CONTROL_HUB.html`.
3. **Automated Verification**:
   * Verified clean HTML structure in `scratch/CM_CONTROL_HUB.html` and passed `Test-WorkspaceReadiness.ps1`.

