# LCM Tool Catalog Database Design Specification

Module: docs/DataDesign-Tools.md  
Purpose: Authoritative data architecture, SQLite schema, constraints, views, and dual-state projection invariants for the LCM Tool Catalog.  
Path: D:/Git_Repositories/LCM_Inventory/docs/DataDesign-Tools.md  
Authors: Rolf, LCM_AI Governance  
Version: 10.2.6  
Status: Authoritative Data Specification  
Date: 2026-11-20 20:48:28  

---

## 1. Executive Summary & Purpose

The **LCM Tool Catalog Database** (`tools.db`) serves as the structured relational catalog powering **`ShowTools`** (`ToolExplorer.html` / `Show-ToolIntents.ps1`), command trampolines (`DoT/`), and execution gateway lookups (`run.cmd`). Governed by `CRP-323`, this store replaces the heavy in-memory parsing of `tool_catalog.json` (~6,000 lines) with a high-performance SQLite engine operating under the **Dual-State Projection Architecture**:
- **Binary Runtime Engine (`data/tools/tools.db`)**: Local, git-ignored SQLite database enabling microsecond filter preset execution and column filtering.
- **Publish Projection (`data/tools/tools.sql`)**: written only at push (`Invoke-LCM_Push.ps1` step 2a) so the pushed state can be rebuilt from the remote; rebuilt into `tools.db` at pull (`--action restore`, git hooks `post-checkout` / `post-merge`); no other use (operator 2026-11-20). Status (CRP-358, 2026-11-20 17:31:10): `config/tool_catalog.json` and `config/tool_intents.json` are retired and deleted; the tables are the only tool store.
- **Go Engine Target**: Structured specifically for zero-copy memory mapping and native Go CLI compilation (`showtools.exe`).

---

## 2. Table Schemas & Constraints

### 2.1 Table: `tools`
Stores all discovered executable tools, short-name trampolines, parameters, and orthogonal classifications.

```sql
CREATE TABLE IF NOT EXISTS tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    intent_id INTEGER UNIQUE, -- Structured Block-Allocated Identifier (-99..-1, 1..99, 1000..9999)
    name TEXT NOT NULL,
    short_name TEXT NOT NULL,
    subsystem TEXT NOT NULL,
    category TEXT NOT NULL,
    audience TEXT NOT NULL,
    admin INTEGER NOT NULL DEFAULT 0 CHECK(admin IN (0, 1)),
    no_exit INTEGER NOT NULL DEFAULT 0 CHECK(no_exit IN (0, 1)),
    type TEXT NOT NULL,
    description TEXT NOT NULL,
    example TEXT,
    relative_path TEXT NOT NULL UNIQUE,
    parameters_json TEXT,
    dependencies_json TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### Constraints & Data Integrity:
- **`intent_id` (UNIQUE)**: Structured integer block allocation (-99..-1 for catch-all, 1..99 for sequential run, 1000..9999 for categorized tiers).
- **`relative_path` (UNIQUE)**: Canonical relative file path (e.g. `SystemConfiguration\Source\@00-RegKeyDefaultTypeSet.cmd`).
- **`short_name` (NOT NULL)**: Clean short alias used for command trampoline generation in `DoT/`.
- **`subsystem` (TEXT NOT NULL)**: Enforces assignment to authoritative Subsystem, eliminating arbitrary folder grouping.
- **`category` (TEXT NOT NULL)**: Restricts categories to condensed functional domains; eliminates legacy non-categories (`Utility`, `Role`).
- **`audience` (TEXT NOT NULL)**: Strictly partitioned into `User`, `Maintenance`, or `Internal`.
- **`admin` (BOOLEAN CHECK)**: Declares whether execution requires Administrator UAC elevation (`RULE-ELEV-001`).

---

### 2.2 Table: `runtimes` (CRP-366, RULE-PY-010)

Interpreter registry: the one place that names which executable runs LCM code. Paths inside the git root are stored relative to it (CRP-253 sandboxing); machine tools outside it stay absolute. Owned by the database, not by the JSON catalog: the catalog sync never deletes it; `ensure_runtimes()` in `tools/sync_tool_catalog_db.py` creates it and inserts missing seed rows; the SQL dump (`data/tools/tools.sql`) carries the current rows as `INSERT OR REPLACE`.

```sql
CREATE TABLE IF NOT EXISTS runtimes (
    runtime_key TEXT PRIMARY KEY,
    executable_path TEXT NOT NULL,
    purpose TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

| runtime_key | executable_path (seed) | Purpose |
|:---|:---|:---|
| `python` | `D:\Tools\Python314\python.exe` | LCM tools, gates, DoT trampolines and AI ad-hoc scripts |
| `python-venv` | `.venv\Scripts\python.exe` (relative to the git root) | Only code that needs the workspace venv packages; always named explicitly |

Tooling: `tools/Get-LcmRuntime.py get <key>` / `list` / `set <key> <path> --purpose` (set only on operator instruction); PowerShell callers `Get-LcmRuntimePath` (`modules/LcmRuntimeAtoms.psm1`); `Update-ToolCatalog.ps1` writes the resolved path into every Python trampoline.

### 2.3 Store columns (CRP-358)

Additive columns; no field was dropped.

| Table | Column | Meaning |
|:---|:---|:---|
| `tools` | `role` TEXT, `domain` TEXT, `intent_elevated` INTEGER | catalog fields that had no column (reconciliation `data/analysis/CRP-358/tool_catalog.md`) |
| `tools` | `parameters_json`, `dependencies_json` | legacy JSON text, kept (never drop) but no longer written; superseded by the child tables below |
| `tool_intents` | `parameters` | legacy JSON text, kept but no longer written; superseded by `intent_parameters` |
| `tool_intents` | `atom_id` INTEGER | the atom that runs the intent (`atoms.atom_id`) |
| `_lcm_tools_db_metadata` | keys `intents_version`, `intents_description`, `intents_updated_at` | header of the intents document |

No document blobs (operator 2026-11-20): lists are child tables; text belongs in `.md` / small `.json` files linked two-way from the tables.

```sql
CREATE TABLE IF NOT EXISTS tool_aliases (tool_id INTEGER NOT NULL, position INTEGER NOT NULL, alias TEXT NOT NULL,
    PRIMARY KEY (tool_id, position));
CREATE TABLE IF NOT EXISTS tool_parameters (tool_id INTEGER NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL,
    type TEXT, mandatory INTEGER NOT NULL DEFAULT 0 CHECK (mandatory IN (0, 1)), default_value TEXT,
    default_kind TEXT NOT NULL DEFAULT 'null' CHECK (default_kind IN ('null', 'text', 'bool', 'int', 'real')),
    description TEXT, PRIMARY KEY (tool_id, position));
CREATE TABLE IF NOT EXISTS tool_dependencies (tool_id INTEGER NOT NULL, position INTEGER NOT NULL,
    dependency TEXT NOT NULL, PRIMARY KEY (tool_id, position));
CREATE TABLE IF NOT EXISTS intent_parameters (intent_id INTEGER NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL,
    value TEXT, value_kind TEXT NOT NULL DEFAULT 'text' CHECK (value_kind IN ('null', 'text', 'bool', 'int', 'real')),
    PRIMARY KEY (intent_id, position));
```

### 2.4 Atoms (CRP-363, `data/analysis/CRP-363/DataDesign-Atoms-Draft.md`)

```sql
CREATE TABLE IF NOT EXISTS atoms (
    atom_id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_path TEXT NOT NULL,          -- relative to the git root, forward slashes, lower case
    entry_point TEXT,                   -- NULL = the whole script
    tool_id INTEGER NOT NULL,           -- owning tool (tools.id); a tool owns 1..n atoms
    elevated INTEGER NOT NULL DEFAULT 0 CHECK (elevated IN (0, 1)),  -- the elevation authority (CRP-343)
    required_switch TEXT,               -- explicit field; NULL until a catalog entry declares one
    runtime_key TEXT,                   -- runtimes.runtime_key; 'python' for .py, NULL for native
    archived_at TEXT,                   -- archive mark; rows are never deleted
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_atoms_script_entry ON atoms(script_path, COALESCE(entry_point, ''));
CREATE TABLE IF NOT EXISTS atom_permissions (tool_id INTEGER NOT NULL, atom_id INTEGER NOT NULL, PRIMARY KEY (tool_id, atom_id));
CREATE TABLE IF NOT EXISTS atom_calls (caller_tool_id INTEGER NOT NULL, atom_id INTEGER NOT NULL, source_path TEXT NOT NULL,
    source_line INTEGER NOT NULL, PRIMARY KEY (caller_tool_id, atom_id, source_path, source_line));
```

- Derived on every store write (`rebuild_atoms`): one atom per intent script, owned by the `tools` row of the same file; an atom whose script disappeared is archived; `atom_permissions` maps the catalog list `tool_atom_permissions` (intent keyed, kept) to atoms.
- `atom_calls` is filled by the call scan of the ShowAtoms step (CRP-363 T3); empty until then.
- View `v_atoms`: one row per atom with owning tool, level (0 TBD, 1 granted, 2 controlled, 3 admin), intent keys, permitted callers and the conflict flag (`elevated = 1` while the owning tool is below level 3).
- State at migration (2026-11-20): 330 atoms, 85 elevated, 6 permissions, 0 conflicts.

## 3. Indexing Strategy

B-Tree indexes optimize single-click filter presets and interactive search across `ShowTools`:

```sql
CREATE INDEX IF NOT EXISTS idx_tools_audience ON tools(audience);
CREATE INDEX IF NOT EXISTS idx_tools_subsystem ON tools(subsystem);
CREATE INDEX IF NOT EXISTS idx_tools_category ON tools(category);
CREATE INDEX IF NOT EXISTS idx_tools_shortname ON tools(short_name);
CREATE INDEX IF NOT EXISTS idx_tools_admin ON tools(admin);
```

---

## 4. Views & Filter Preset Queries

### 4.1 View: `v_user_tools` (Preset: User / Default)
Returns only tools intended for daily operator execution (`Audience = 'User'`), reducing the visual catalog to the ~30 primary commands.

```sql
CREATE VIEW IF NOT EXISTS v_user_tools AS
SELECT 
    id, short_name, name, subsystem, category, admin, description, example, relative_path
FROM tools
WHERE audience = 'User'
ORDER BY short_name ASC;
```

### 4.2 View: `v_developer_tools` (Preset: Developer / NoInternals)
Provides the full subsystem engineering toolset across `User` and `Maintenance`, while keeping internal runtime engines hidden unless explicitly selected.

```sql
CREATE VIEW IF NOT EXISTS v_developer_tools AS
SELECT 
    id, short_name, name, subsystem, category, audience, admin, description, example, relative_path
FROM tools
WHERE audience IN ('User', 'Maintenance')
ORDER BY subsystem ASC, short_name ASC;
```

### 4.3 View: `v_maintenance_tools` (Preset: Maintenance)
Focuses exclusively on system parameters, invariant enforcers, hardware controls, and repair utilities.

```sql
CREATE VIEW IF NOT EXISTS v_maintenance_tools AS
SELECT 
    id, short_name, name, subsystem, category, admin, description, example, relative_path
FROM tools
WHERE audience = 'Maintenance'
ORDER BY subsystem ASC, short_name ASC;
```

---

## 5. Tools & Database Synchronization Utilities

| Tool | Path | Responsibility |
| :--- | :--- | :--- |
| **`Update-ToolCatalog.ps1`** | [`tools/Update-ToolCatalog.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Update-ToolCatalog.ps1) | Primary AST scanner discovering scripts, extracting parameters, and generating `DoT/` trampolines. |
| **`sync_tool_catalog_db.py`** | `tools/sync_tool_catalog_db.py` | The only writer and reader of the tool store (CRP-358): `export` / `import` (`--store catalog\|intents`), `record-call`, `sync` (schema, atoms), `verify` (integrity), `dump` (`tools.sql`, at push only), `restore` (`tools.sql` -> `tools.db`, at pull), `migrate` (one-time JSON reconciliation from `--json-dir`, done 2026-11-20). `LCM_TOOLS_DB_PATH` redirects it to an isolated copy for tests. PowerShell callers use `Get-LcmToolStoreDocument` / `Save-LcmToolStoreDocument` (`modules/LcmToolCatalog.psm1`). |
| **`Sync-LcmToolCatalogDb.ps1`** | `tools/Sync-LcmToolCatalogDb.ps1` | PowerShell quality gate and CI/CD wrapper for the tool catalog database. |
| **`Show-ToolIntents.ps1`** | [`tools/Show-ToolIntents.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Show-ToolIntents.ps1) | CLI entrypoint querying `tools.db` directly to render text tables or launch `ToolExplorer.html`. |
| **`Test-LcmToolCatalogDb.Tests.ps1`** | `tests/Test-LcmToolCatalogDb.Tests.ps1` | Pester test suite verifying schema constraints, dual-state sync, and view definitions. |
