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
| `Configuration Management`, `Proposal Review`, `Tool Analysis`, `Tool Discovery`, `Tool Scaffolding`, `Rules`, `Strategies / RFCs` | **`Governance & Proposals`** |
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

---

### 5. Integration with `ShowTools` & `ShowCM`

1. **`ShowTools` (`ToolExplorer.html` / `Show-ToolIntents.ps1`)**:
   - The primary interactive viewer for the 3-axis taxonomy.
   - The table drops the obsolete `Role` column to eliminate layout clutter and maximize space for descriptions.
   - The `Group` column and filter are renamed to `SubSystem`.
   - The Preset Selector bar is positioned prominently at the top with `User` as the default.

2. **`ShowCM` (`CM_CONTROL_HUB.html` / `Show-LcmControl.ps1`)**:
   - The Control Hub redesign aligns proposals and change requests with the unified `SubSystem` model (`PC`, `LCM`, `LCM_Inventory`, `LCM_AI`, `LCM_Tools`, `HaSSD06`, `Sandboxes`).
   - Obsolete role/group terminology is removed from the dashboard widgets and ledger displays.

---

### 6. SQLite Tool Catalog Engine (`tools.db` & `tools.sql`)

Following the Dual-State Projection Architecture proven in `CRP-322`, `tool_catalog.json` is paired with a high-performance SQLite database:

```sql
CREATE TABLE IF NOT EXISTS tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    short_name TEXT NOT NULL,
    subsystem TEXT NOT NULL,
    category TEXT NOT NULL,
    audience TEXT NOT NULL, -- 'User', 'Maintenance', 'Internal'
    admin INTEGER NOT NULL DEFAULT 0,
    no_exit INTEGER NOT NULL DEFAULT 0,
    type TEXT NOT NULL, -- 'PowerShell', 'Python', 'Batch', 'Executable'
    description TEXT,
    example TEXT,
    relative_path TEXT NOT NULL,
    parameters_json TEXT,
    dependencies_json TEXT,
    updated_at TEXT NOT NULL
);

-- Targeted indexes for sub-millisecond ShowTools preset & column filtering
CREATE INDEX IF NOT EXISTS idx_tools_audience ON tools(audience);
CREATE INDEX IF NOT EXISTS idx_tools_subsystem ON tools(subsystem);
CREATE INDEX IF NOT EXISTS idx_tools_category ON tools(category);
CREATE INDEX IF NOT EXISTS idx_tools_shortname ON tools(short_name);
```

#### Dual-State Properties:
1. **Binary Store (`data/tools/tools.db`)**: Local runtime database, git-ignored (`RULE-REV-001`), loaded instantly by `ShowTools` without JSON deserialization overhead.
2. **Text Store (`data/tools/tools.sql`)**: Deterministic SQL dump committed to Git for transparent diffs in Beyond Compare.
3. **Synchronization**: Bidirectional sync between `tool_catalog.json` and `tools.db` via `Sync-LcmToolCatalogDb.ps1` / Python sync atom.
4. **Go Engine Readiness**: Providing an SQLite database opens the immediate path for a compiled Go binary (`showtools.exe` / `lcm.exe`) with microsecond response times.
