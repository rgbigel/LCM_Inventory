---
Bug-ID: BUG-127
Scope: LCM_Inventory
Version: 10.2.0
Affected-Repos: [LCM_Inventory]
Severity: High
Status: In-Progress
Date: 2026-10-13
Author: Operator Directive / Bug Intake
Root-Cause: Desynchronization between header metadata, script runtime version variables, and UI/dashboard tables in Control Hub (CM_CONTROL_HUB.html, Show-CmControlHub.ps1, and tool documentation parsers), causing stale or hardcoded tool versions to be displayed in tables, console feeds, and logs.
---

# BUG-127: Control Hub Table and Runtime Tool Version Desynchronization Across Messages, Logs, and UI Tables

## 1. Issue Summary
When permanent tools or PowerShell scripts undergo version updates (e.g. `Show-CmControlHub.ps1` updated from `10.0.0` to `10.0.0`), the tabular displays, console output, and logs within the Control Hub do not consistently reflect the updated tool version. The correct version must be deterministically propagated and displayed across all messages, logs, and tabular interfaces.

## 2. Root Cause & Architectural Decision
1. **Fragile Client-Side Regex Guessing**: Previously, the HTML dashboard relied on client-side JavaScript regexes (`extractDocMetadata`) executed at runtime in the browser to guess version strings from raw text strings, which frequently fell back to defaults (`10.0.0`) or missed internal script variables (`$scriptVersion`).
2. **Hardcoded Header Strings**: Static version labels in `<title>` and `<h1>` (e.g. `V10.0.0`) were out of sync with the active LCM baseline and tool versions.
3. **Compile-Time Pre-Compilation Invariant**: Rather than guessing dynamically at runtime in the browser, the authoritative tool and document versions must be extracted and pre-compiled directly during the PowerShell compilation step (`Show-CmControlHub.ps1`), baking a verified metadata catalog (`RAW_COMPILED_CATALOG`) and explicit template tokens directly into the rendered HTML.
4. **Dedicated Version Subtitle Layout**: Because the full versioning string (Tool version, LCM baseline version, and build timestamp) is long, it is displayed on a dedicated subtitle line below the main heading rather than crowding the primary title bar.

## 3. Criticality Assessment
- **Severity**: HIGH
- **Impact**: Operator and audit logs report inconsistent tool versions; discrepancies between UI table displays and actual executing scripts impair configuration management transparency and traceability.

## 4. Affected Scope
- `LCM_Inventory/tools/Show-CmControlHub.ps1`
- `LCM_Inventory/docs/CM_CONTROL_HUB.html`
- `LCM_Inventory/data/proposals/proposals.json`

## 5. Implementation Specifications
1. **Compile-Time Static Token Replacement**:
   - `<title>{{HUB_TITLE}}</title>`
   - `<h1>LCM Configuration Management Control Hub</h1>` with dedicated subtitle line:
     `<div class="header-version-subtitle">{{HUB_VERSION_SUBTITLE}}</div>`
   - Console stream initialization banners bound to `{{HUB_VERSION}}`.
2. **PowerShell AST & Header Version Extraction**:
   - `Show-CmControlHub.ps1` extracts `$scriptVersion` / `$VERSION` assignment variables and DOX headers (`Version: M.m.p`) during compilation.
   - Pre-computes `RAW_COMPILED_CATALOG` containing exact name, role, version, date, and review state for each tool and document.
3. **Pure Presentation Binding in Browser**:
   - `CM_CONTROL_HUB.html` renders directly from `RAW_COMPILED_CATALOG`, eliminating client-side regex parsing.
