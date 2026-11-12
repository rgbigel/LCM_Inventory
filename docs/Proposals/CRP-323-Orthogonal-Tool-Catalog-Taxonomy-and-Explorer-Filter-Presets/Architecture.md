# Architecture: CRP-323

## Orthogonal Tool Catalog Taxonomy & Preset Engine Architecture

### 1. Conceptual Dimensional Matrix

```
+---------------------------------------------------------------------------------------------------+
|                                          TOOL EXPLORER                                            |
+---------------------------------------------------------------------------------------------------+
|  PRESETS (Composite View Filters)                                                                 |
|  [ * User (Default) * ]  [ Developer (NoInternals) ]  [ Maintenance ]  [ All ]                     |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  DIMENSION 1: AUDIENCE (Target Invoker)                                                           |
|  +--------------------+----------------------------+-------------------------------+              |
|  | User (Daily Ops)   | Maintenance (System Maint) | Internal (Runtime/Automation) |              |
|  +--------------------+----------------------------+-------------------------------+              |
|                                                                                                   |
|  DIMENSION 2: SUBSYSTEM (Target Subsystem / Boundary — Replaces "Group")                          |
|  +---------------------------------------------------------------------------------------------+  |
|  | PC (SystemConfig) | LCM | LCM_Inventory | LCM_AI | LCM_Tools | HaSSD06 | Sandboxes (Future) |  |
|  +---------------------------------------------------------------------------------------------+  |
|                                                                                                   |
|  DIMENSION 3: CATEGORY (Functional Domain & Resource — Absorbs "Role")                            |
|  +---------------------------------------------------------------------------------------------+  |
|  | 1. File System & Search            6. Diagnostics & Telemetry                               |  |
|  | 2. Backup & Recovery               7. Configuration & Customization                         |  |
|  | 3. Governance & Proposals          8. Environment & Runtimes                                |  |
|  | 4. Review & Quality Gates          9. Execution Gateway                                     |  |
|  | 5. Elevation & Access                                                                        |  |
|  +---------------------------------------------------------------------------------------------+  |
|                                                                                                   |
|  [ROLE COLUMN ELIMINATED: Its action verbs are absorbed directly into Category]                   |
+---------------------------------------------------------------------------------------------------+
```

---

### 2. Category Consolidation & Role Absorption Mapping

The table below defines how the legacy 40 fragmented categories and 15 legacy roles map cleanly into the new 9 functional categories:

| Legacy Categories & Absorbed Roles | New Unified Category (9) |
| :--- | :--- |
| `File Search`, `Explorer Tweaks`, `Disk Diagnostics`, `Volume Security`, `FileReadIntegrity` | **`File System & Search`** |
| `Macrium BCR Baseline`, `Disaster Recovery`, `RestorePoints`, `Backup` | **`Backup & Recovery`** |
| `Configuration Management`, `Proposal Review`, `Tool Analysis`, `Tool Discovery`, `Tool Scaffolding`, `Rules` | **`Governance & Proposals`** |
| `Beyond Compare Review`, `Quality Gate`, `Audit Logs`, `Drift Detection`, `AsciiCompliance`, `Readiness` | **`Review & Quality Gates`** |
| `Administrative Privileges`, `JIT Authentication`, `Security Tweaks`, `System Security`, `Role: Elevation`, `Role: Auth` | **`Elevation & Access`** |
| `Log Diagnostics`, `Network Diagnostics`, `Session Failure Analysis`, `Supervision & Health`, `Telemetry`, `Metrics` | **`Diagnostics & Telemetry`** |
| `System Customization`, `System Fonts`, `System Invariants`, `System Setup`, `Hardware Stability`, `Desktop Personalization`, `Registry Tweaks`, `Regional Settings` | **`Configuration & Customization`** |
| `Environment Setup`, `Runtime Parity`, `PATH Management`, `Module Sync`, `Python Runtimes`, `Virtual Environments` | **`Environment & Runtimes`** |
| `Execution Gateway`, `Action Dispatcher`, `Trampolines`, `Daemon Forwarding`, `do`, `run` | **`Execution Gateway`** |

---

### 3. SubSystem Unification

All boundaries are now recognized as first-class **`SubSystem`** entries:

| SubSystem Identifier | Description & Scope |
| :--- | :--- |
| **`PC`** | Host Windows PC, hardware suppression, system settings, desktop personalization (`SystemConfiguration`). |
| **`LCM`** | Cross-repository Lifecycle Model governance, specifications, rules engine. |
| **`LCM_Inventory`** | Central tools catalog, command trampolines, proposals ledger, progress telemetry. |
| **`LCM_AI`** | Governance rules hub, decision cascade, AI agent instructions and analysis. |
| **`LCM_Tools`** | Diagnostics, reasoning analysis tools, operator research snapshots. |
| **`HaSSD06`** | Home Assistant OS subsystem (devices, sensors, core updates, MQTT/Tuya). |
| **`Sandboxes`** | Isolated execution worktrees, temporary multi-workspace clones, sandboxed testbeds. |

---

### 4. Preset Definitions in `ToolExplorer.html`

The Tool Explorer UI filter engine will support single-click Preset buttons:

```javascript
const PRESETS = {
  user: {
    label: "User (Default)",
    description: "Daily operational commands and workflows",
    audiences: ["User"]
  },
  developer: {
    label: "Developer",
    description: "Engineering suite: Subsystem manipulators (Default: NoInternals)",
    audiences: ["User", "Maintenance"] // 'Internal' can be included via orthogonal Audience column filter
  },
  maintenance: {
    label: "Maintenance",
    description: "System and subsystem parameters, repairs, and invariant enforcers",
    audiences: ["Maintenance"]
  },
  all: {
    label: "All Tools",
    description: "Unfiltered workspace inventory",
    audiences: ["User", "Maintenance", "Internal"]
  }
};
```
