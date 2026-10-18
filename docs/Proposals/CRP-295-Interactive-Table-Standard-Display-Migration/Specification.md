# Change Request Proposal: CRP-295

```yaml
CRP-ID: CRP-295
Title: Interactive Table Standard Display Migration
Scope: Tool Explorer, Workspace Inventory, and HA Inventory
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-10-18
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
Dependency: CRP-293 accepted reference; CRP-292 Accepted Common Goal
```

---

## 1. Goal Reference

Implements the Accepted Common Goal in [CRP-292 Specification.md](../CRP-292-Standard-Display-Atom-and-Adoption-Programme/Specification.md).

## 2. Scope

Apply reusable dense-table atoms to:

- [Show-ToolsExplorer.ps1](../../../tools/Show-ToolsExplorer.ps1) and
  [lcm-tool-explorer.js](../../../assets/lcm-tool-explorer.js)
- [Show-WorkspaceInventoryApp.ps1](../../../tools/Show-WorkspaceInventoryApp.ps1)
  and [WORKSPACE_INVENTORY_VIEWER.html](../../../assets/WORKSPACE_INVENTORY_VIEWER.html)
- [Show-HaInventoryApp.ps1](../../../../HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1)

## 3. Requirements

- Reuse shared table, qualified-search, filter, match-counter, selection,
  modal/error, and stable-layout atoms where their contracts fit.
- Preserve data-specific columns, row actions, export/print behavior, and
  existing navigation/deep-link contracts.
- For mutations, submit typed controller intents with explicit target and
  revision; never replicate generic shell command construction.
- Prevent clipped menus/dialogs, dynamic column shifts, false success, and
  ambiguous multi-row action targets.
- Maintain cross-repository ownership: HA-specific mutation/data behavior stays
  in its owning repository or declared public contract.

## 4. Acceptance Criteria

- Dense tables retain stable columns, sticky headers, responsive scroll
  behavior, and accessible selection indication.
- Filter/search/selection behavior is atom-tested against each display's
  payload.
- Mutating actions have preview, pending lock, structured error, persisted
  confirmation, and disposable integration coverage.
- Each display’s existing public actions remain discoverable and functional.

## 5. Non-Goals

- No cross-repository data mutation outside public contracts.
- No forced convergence of distinct inventory schemas.
- No start before CRP-293 acceptance.
