# CRP-212: JSON-Primary Governance Inventory and ShowTools Nomenclature Reconciliation

```yaml
CRP-ID: CRP-212
Priority: 8
Scope: Workspace Governance, Inventory Data Models, Command Aliasing, and Session History
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Affected-Repos:
  - LCM_Inventory
  - LCM_AI
  - LCM_Tools
```

## Objective

Establish structured JSON datasets in `LCM_Inventory` as the authoritative primary source of truth for the Lifecycle Model (LCM) methodology, while positioning Markdown (`.md`) as rendered presentation artifacts generated and surfaced through Show-type viewers.
Reconcile command nomenclature by reinstating `ShowTools` as the primary canonical bare-word command, while retaining `ToolsExplorer` / `ToolExplorer` as compatibility aliases.
Formally ratify `.agents/ACTIVE_SESSION.md` and `.agents/ACTIVE_CONTEXT.md` as permanently tracked session history in `LCM_AI`.
Codify the standard deferral semantic for UI controls displaying `"Available in a later lifecycle-action release"`.

---

## 1. JSON as Primary Source of Truth

1. **Inventory Architecture**:
   - `LCM_Inventory` holds authoritative `.json` records (`inventory.json`, `proposals.json`, `apps.json`, `tracking_policy.json`).
   - All tool automation, quality gates, and status synchronization scripts read directly from these JSON schemas.
2. **Markdown Presentation Viewers**:
   - Markdown documents (`LCM-Repository-Inventory.md`, `LCM-Rules-Cross-Reference.md`, `Architecture.md`) serve as human-readable views and audit documentation generated or validated against the JSON primary source.
   - Show-type displays (`Show-LcmControl.ps1`, `Show-ToolsExplorer.ps1`, `Show-HaInventoryApp.ps1`) render and present this data interactively in the browser/IDE canvas.

---

## 2. Command Nomenclature Reconciliation: `ShowTools` vs. `ToolsExplorer`

1. **Primary Command**:
   - **`ShowTools`** is restored as the canonical, authoritative bare-word command across all documentation, trampolines (`LCM_Inventory/Cmd/ShowTools.cmd`), and tool catalog definitions.
2. **Compatibility Aliasing**:
   - `ToolsExplorer.cmd` and `ToolExplorer.cmd` remain available as functional aliases redirecting to `ShowTools`.
   - Macros and rules index `ShowTools` as the primary operational entrypoint.

---

## 3. Session State History Tracking Policy

1. **Physical Tracking Invariant**:
   - Active session handoff memory files (`LCM_AI/.agents/ACTIVE_SESSION.md` and `ACTIVE_CONTEXT.md`) are recognized as vital living session history.
   - They MUST be committed and pushed to GitHub as part of `LCM_AI` repository history.
2. **Clean `.gitignore` Boundaries**:
   - The physical repository `LCM_AI` ignores only transient runtime artifacts (`.agents/logs/`, `.agents/scratch/`, `*.log`, `*.tmp`, `*.bak`).
   - Blanket ignores (`.agents/*`) are strictly reserved for consumer junction repositories.

---

## 4. Deferral Directive Policy ("Available in a later lifecycle-action release")

1. **Standard Semantic**:
   - In UI dashboards and tools (such as `CM_CONTROL_HUB.html`), action controls bearing the notice `"Available in a later lifecycle-action release"` explicitly declare deferred scope.
   - Agents and operators SHALL NOT implement or trigger these controls during rapid batch-completion cycles; they are deferred to dedicated follow-on proposals.
