# CRP-250: Registry-Authoritative Runtime Topology and GoodNight Lifecycle

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-250` |
| **Lifecycle State** | `IN_PROGRESS` |
| **Origin Repository** | `LCM_Inventory` |
| **Date** | 2026-10-07 |
| **Flow Mode** | DOIT |

## Objective

Remove active retired `.lcm` runtime paths and inherited-environment workspace
authority. PowerShell tools and command launchers must resolve `Git_Root` only
from the machine environment registry key. Establish GoodNight as a
non-destructive archive-before-publish lifecycle, while reserving GoodMorning
for a later, separately approved converse workflow.

## Scope

- Create one shared machine-registry `Git_Root` resolver with explicit
  validation and no hard-coded or environment fallback.
- Migrate active `LCM_Inventory\Cmd` launchers from inherited `%Git_Root%` to
  a registry-query preamble.
- Replace active `LCM_Inventory\tools`, `LCM_Inventory\modules`, and `LCM_Inventory\Cmd` paths with
  Inventory-owned locations.
- Select and migrate the canonical Inventory-owned catalog/config location.
- Preserve `LCM_Inventory\archive` as archive-only historical material.
- Archive daemon-log evidence before GoodNight delegates to publish.
- Permit `COPILOT_AGENT_SESSION_ID`, `COPILOT_HOME`, and `USERPROFILE` only
  for Copilot runtime session discovery in `Export-CopilotSessionHandoff.ps1`.

## Non-Goals

- Do not implement GoodMorning until its explicit behavior is designed.
- Do not treat Copilot runtime discovery as workspace-root authority.
- Do not truncate or delete daemon logs from GoodNight itself.
