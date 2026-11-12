# LCM Tool Catalog Database Design Specification

Module: docs/DataDesign-Tools.md  
Purpose: Authoritative data architecture, SQLite schema, constraints, views, and dual-state projection invariants for the LCM Tool Catalog.  
Path: D:/Git_Repositories/LCM_Inventory/docs/DataDesign-Tools.md  
Authors: Rolf, LCM_AI Governance  
Version: 10.2.3  
Status: Authoritative Data Specification  
Date: 2026-11-12  

---

## 1. Executive Summary & Purpose

The **LCM Tool Catalog Database** (`tools.db`) serves as the structured relational catalog powering **`ShowTools`** (`ToolExplorer.html` / `Show-ToolIntents.ps1`), command trampolines (`DoT/`), and execution gateway lookups (`run.cmd`). Governed by `CRP-323`, this store replaces the heavy in-memory parsing of `tool_catalog.json` (~6,000 lines) with a high-performance SQLite engine operating under the **Dual-State Projection Architecture**:
- **Binary Runtime Engine (`data/tools/tools.db`)**: Local, git-ignored SQLite database enabling microsecond filter preset execution and column filtering.
- **Textual Baseline (`data/tools/tools.sql` & `config/tool_catalog.json`)**: Deterministic SQL and JSON ledger files committed to Git for transparent diffs, code reviews, and AST tracking.
- **Go Engine Target**: Structured specifically for zero-copy memory mapping and native Go CLI compilation (`showtools.exe`).

---

## 2. Table Schemas & Constraints

### 2.1 Table: `tools`
Stores all discovered executable tools, short-name trampolines, parameters, and orthogonal classifications.

```sql
CREATE TABLE IF NOT EXISTS tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    short_name TEXT NOT NULL,
    subsystem TEXT NOT NULL CHECK(subsystem IN ('PC', 'LCM', 'LCM_Inventory', 'LCM_AI', 'LCM_Tools', 'HaSSD06', 'Sandboxes')),
    category TEXT NOT NULL CHECK(category IN (
        'File System & Search',
        'Backup & Recovery',
        'Governance & Proposals',
        'Review & Quality Gates',
        'Elevation & Access',
        'Diagnostics & Telemetry',
        'Configuration & Customization',
        'Environment & Runtimes',
        'Execution Gateway'
    )),
    audience TEXT NOT NULL CHECK(audience IN ('User', 'Maintenance', 'Internal')),
    admin INTEGER NOT NULL DEFAULT 0 CHECK(admin IN (0, 1)),
    no_exit INTEGER NOT NULL DEFAULT 0 CHECK(no_exit IN (0, 1)),
    type TEXT NOT NULL CHECK(type IN ('PowerShell', 'Python', 'Batch', 'Executable')),
    description TEXT NOT NULL,
    example TEXT,
    relative_path TEXT NOT NULL,
    parameters_json TEXT,
    dependencies_json TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### Constraints & Data Integrity:
- **`name` (UNIQUE)**: Canonical filename (e.g. `Search-Everything.ps1`, `run.cmd`).
- **`short_name` (NOT NULL)**: Clean short alias used for command trampoline generation in `DoT/`.
- **`subsystem` (CHECK)**: Enforces assignment to one of the 7 authoritative Subsystems, eliminating arbitrary folder grouping.
- **`category` (CHECK)**: Restricts categories to the 9 condensed functional domains; eliminates legacy non-categories (`Utility`, `Role`).
- **`audience` (CHECK)**: Strictly partitioned into `User`, `Maintenance`, or `Internal`.
- **`admin` (BOOLEAN CHECK)**: Declares whether execution requires Administrator UAC elevation (`RULE-ELEV-001`).

---

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
| **`sync_tool_catalog_db.py`** | `tools/sync_tool_catalog_db.py` | High-speed synchronization between `tool_catalog.json`, `tools.db`, and `tools.sql`. |
| **`Sync-LcmToolCatalogDb.ps1`** | `tools/Sync-LcmToolCatalogDb.ps1` | PowerShell quality gate and CI/CD wrapper for the tool catalog database. |
| **`Show-ToolIntents.ps1`** | [`tools/Show-ToolIntents.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Show-ToolIntents.ps1) | CLI entrypoint querying `tools.db` directly to render text tables or launch `ToolExplorer.html`. |
| **`Test-LcmToolCatalogDb.Tests.ps1`** | `tests/Test-LcmToolCatalogDb.Tests.ps1` | Pester test suite verifying schema constraints, dual-state sync, and view definitions. |
