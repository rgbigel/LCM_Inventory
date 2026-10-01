# Implementation Plan: CRP-163

```yaml
CRP-ID: CRP-163
Title: Master Tripartite Architecture Visibility, Catalog Indexing & Cross-App Governance Focus
Scope: LCM Governance, LCM_Inventory & Governed Child Repositories
Baseline-Version: v7.6.0
Author: Rolf, LCM_AI Engine
Date: 2026-09-20
Status: Suggested
Plan-State: suggested
Progress-State: queued
Priority: High
```

---

## 1. Technical Components & Proposed Changes

### Component 1: `modules/ProposalManager.psm1`
- **`Get-LcmApps`**: Iterate over repositories and synthesize entry 0 (`id: 'Master'`, `number: 0`, `is_master: true`, `doc_layout: 'MasterRoot'`) tracking presence of `Architecture.md`, `Requirements.md`, and `Implementation.md`.
- **`Set-ActiveAppContext`**: Support `'Master'`, `'Architecture'`, `'Base'`, `'Root'`, `'0'`, `'App: 0'`, `'A0'` setting `app_id: 'Master'` (or `'Architecture'`) and `app_title: 'Master Tripartite Architecture (Governing All Apps)'`.
- **`Format-LcmAppsTable`**: Render Master row with cyan/green highlighting when active focus is Master/Base.
- **Constituent Manifest Parsing**: Filter out markdown table delimiter rows (`:---`).

### Component 2: `tools/Invoke-ProposalAction.ps1`
- **`workon` Action**: Clearly print `Current Active Focus: 🏛️ Master Architecture (Governing All Apps) [<Repo>]` when context is null, Master, or Base.

### Component 3: `tools/Show-CmControlHub.ps1`
- **`docsCache` Pre-Compilation**: Index normalized shorthand keys (`$r/Architecture.md`, `$r/Requirements.md`, `$r/Implementation.md`) to guarantee instant modal loading.

### Component 4: `assets/CM_CONTROL_HUB.html`
- **`appsModal` Guidance Banner**: Add guidance banner explaining Master Documents role.
- **`updateHeaderFocusBadge()`**: Display `Focus: 🏛️ Master Architecture` with purple badge.
- **`renderAppsTable()`**: Render `🏛️ Master` row with interactive `A` · `R` · `I` links, `🏛️ Focus Master` button, and `📚 Master Docs` review button.

---

## 2. Verification Strategy

1. **Unit Tests**: Run `Invoke-Pester -Path 'LCM_Inventory/tests/ProposalManager.Tests.ps1' -Output Detailed` (21/21 passing).
2. **Catalog Compilation**: Run `Sync-LcmAppCatalog.ps1` and verify `data/catalog/apps.json`.
3. **Control Hub Dashboard**: Run `Show-CmControlHub.ps1 -NoLaunch` to ensure clean compilation.
