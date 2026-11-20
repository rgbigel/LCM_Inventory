#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module: tools/sync_tool_catalog_db.py
Purpose: High-speed SQLite synchronization, canonical SQL text projection, and query engine
         for LCM Tool Catalog and Tool Intents under Dual-State Projection architecture.
Path: LCM_Inventory/tools/sync_tool_catalog_db.py
Authors: Rolf, LCM_AI Engine, Claude
Version: 10.2.9
Status: Production Engine
Date: 2026-11-20 17:21:19
Implementation Choices (CRP-343 segment 2): tools.admin is a level 0 = TBD, 1 = granted, 2 = controlled, 3 = admin
(legacy JSON booleans: true -> 3, false -> 1); table tool_atom_permissions holds the elevated atoms a controlled tool
may call (catalog field AllowedAtoms).
Implementation Choices (CRP-366): table runtimes is the interpreter registry (RULE-PY-010). It is owned by the
database, not by the JSON catalog: the sync never deletes it, seed rows are inserted only when missing
(ensure_runtimes), and the SQL dump carries the current rows. Paths inside the git root are stored relative to it
(operator 2026-11-19, CRP-253 sandboxing); machine tools outside the root stay absolute.
Implementation Choices (CRP-358, CRP-363; revised 2026-11-20 20:45:56 after the operator review): the tables are the
only tool store and hold scalar columns and child tables only - no document blobs (tool_aliases,
tool_parameters, tool_dependencies, intent_parameters; the legacy JSON-text columns parameters_json,
dependencies_json and tool_intents.parameters are kept but no longer written). export rebuilds the document
shape the retired JSON files had; import is the only writer; reads open mode=ro, record-call skips the schema
setup, busy_timeout 5000 ms. tools.sql is the publish projection only: dump runs at push, restore rebuilds
tools.db from it after a pull; no other use. atoms / atom_permissions / atom_calls and v_atoms follow
data/analysis/CRP-363/DataDesign-Atoms-Draft.md. LCM_TOOLS_DB_PATH redirects the store for tests.
"""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import sqlite3
import sys

sys.stdout.reconfigure(encoding="utf-8")


def admin_level(value):
    """CRP-343: tools.admin level 0..3; legacy booleans true -> 3, false -> 1; anything else -> 0 (TBD)."""
    if value is True:
        return 3
    if value is False:
        return 1
    try:
        level = int(value)
    except (TypeError, ValueError):
        return 0
    return level if 0 <= level <= 3 else 0


def get_default_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    workspace_root = os.path.dirname(repo_root)

    tools_json_path = os.path.join(repo_root, "config", "tool_catalog.json")
    intents_json_path = os.path.join(repo_root, "config", "tool_intents.json")

    db_dir = os.path.join(repo_root, "data", "tools")
    os.makedirs(db_dir, exist_ok=True)

    db_path = os.path.join(db_dir, "tools.db")
    sql_path = os.path.join(db_dir, "tools.sql")
    return tools_json_path, intents_json_path, db_path, sql_path, workspace_root


def get_lcm_version(repo_root):
    inv_path = os.path.join(repo_root, "data", "inventory.json")
    if os.path.exists(inv_path):
        try:
            with open(inv_path, "r", encoding="utf-8") as f:
                inv = json.load(f)
            baseline = inv.get("workspace_ai_baseline", {})
            return baseline.get("GlobalLCMVersion", "10.2.4")
        except Exception:
            pass
    return "10.2.4"


RUNTIME_SEED = [
    ("python", "D:\\Tools\\Python314\\python.exe",
     "LCM tools, gates, DoT trampolines and AI ad-hoc scripts"),
    ("python-venv", ".venv\\Scripts\\python.exe",  # inside the git root: relative to it
     "only code that needs the workspace venv packages (google-antigravity SDK); always named explicitly"),
]


def ensure_runtimes(conn):
    """CRP-366: creates the interpreter registry if missing and inserts the seed rows that are not there yet."""
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS runtimes (
            runtime_key TEXT PRIMARY KEY,
            executable_path TEXT NOT NULL,
            purpose TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    conn.executemany(
        "INSERT OR IGNORE INTO runtimes (runtime_key, executable_path, purpose) VALUES (?, ?, ?)", RUNTIME_SEED
    )
    conn.commit()


def init_db(conn, workspace_root=None, workspace_role="LIVE", lcm_version="10.2.4"):
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS _lcm_tools_db_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    now_iso = datetime.now().isoformat()
    metadata = [
        ("schema_version", "1.0.0"),
        ("lcm_version", lcm_version),
        ("workspace_root", workspace_root or "D:\\Git_Repositories"),
        ("workspace_role", workspace_role),
        ("last_synced_at", now_iso),
    ]
    cursor.executemany(
        """
        INSERT INTO _lcm_tools_db_metadata (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value=excluded.value
        """,
        metadata,
    )

    # Table: tools (subsystem column strictly named SubSystem / subsystem)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS tools (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            short_name TEXT NOT NULL,
            subsystem TEXT NOT NULL,
            category TEXT NOT NULL,
            audience TEXT NOT NULL,
            admin INTEGER NOT NULL DEFAULT 0,
            no_exit INTEGER NOT NULL DEFAULT 0,
            type TEXT NOT NULL,
            description TEXT,
            example TEXT,
            relative_path TEXT NOT NULL UNIQUE,
            parameters_json TEXT,
            dependencies_json TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tools_audience ON tools(audience)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tools_subsystem ON tools(subsystem)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tools_category ON tools(category)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tools_shortname ON tools(short_name)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tools_admin ON tools(admin)")

    # Table: tool_intents (subsystem column strictly named SubSystem / subsystem)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS tool_intents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            intent_key TEXT NOT NULL UNIQUE,
            goal TEXT NOT NULL,
            executable TEXT,
            script TEXT,
            parameters TEXT,
            trampoline TEXT,
            elevated INTEGER NOT NULL DEFAULT 0,
            subsystem TEXT NOT NULL,
            category TEXT,
            audience TEXT,
            role TEXT,
            call_count INTEGER NOT NULL DEFAULT 0,
            last_called_at TEXT,
            last_duration_ms INTEGER NOT NULL DEFAULT 0,
            total_duration_ms INTEGER NOT NULL DEFAULT 0,
            is_primary_intent INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intents_subsystem ON tool_intents(subsystem)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intents_category ON tool_intents(category)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intents_audience ON tool_intents(audience)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intents_trampoline ON tool_intents(trampoline)")

    # Table: tool_atom_permissions (CRP-343: elevated atoms a controlled tool may call through the DO)
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS tool_atom_permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tool_relative_path TEXT NOT NULL,
            intent_key TEXT NOT NULL,
            UNIQUE (tool_relative_path, intent_key)
        )
        """
    )

    # Standard Views
    cursor.execute(
        """
        CREATE VIEW IF NOT EXISTS v_user_tools AS
        SELECT id, short_name, name, subsystem, category, admin, description, example, relative_path
        FROM tools
        WHERE audience = 'User'
        ORDER BY short_name ASC
        """
    )
    cursor.execute(
        """
        CREATE VIEW IF NOT EXISTS v_developer_tools AS
        SELECT id, short_name, name, subsystem, category, audience, admin, description, example, relative_path
        FROM tools
        WHERE audience IN ('User', 'Developer')
        ORDER BY subsystem ASC, short_name ASC
        """
    )
    cursor.execute(
        """
        CREATE VIEW IF NOT EXISTS v_tool_intents_summary AS
        SELECT intent_key, goal, trampoline, subsystem, category, audience, elevated, call_count, last_called_at
        FROM tool_intents
        ORDER BY subsystem ASC, intent_key ASC
        """
    )
    conn.commit()
    ensure_runtimes(conn)


def resolve_db_path(default_db_path):
    """CRP-358: LCM_TOOLS_DB_PATH redirects the store (tests use an isolated copy, never the live store)."""
    override = os.environ.get("LCM_TOOLS_DB_PATH", "").strip()
    return override if override else default_db_path


def column_names(conn, table):
    return [row[1] for row in conn.execute(f"PRAGMA table_info({table})")]


def add_column_if_missing(conn, table, column, definition):
    if column not in column_names(conn, table):
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def drop_column_if_present(conn, table, column):
    """Removes the document columns added and withdrawn within CRP-358 (never committed; operator 2026-11-20:
    no document blobs in the tables)."""
    if column in column_names(conn, table):
        conn.execute(f"ALTER TABLE {table} DROP COLUMN {column}")


def ensure_store_schema(conn):
    """CRP-358 / CRP-363: scalar columns and child tables only (no document blobs), atom tables."""
    drop_column_if_present(conn, "tools", "raw_json")
    drop_column_if_present(conn, "tools", "aliases_json")
    drop_column_if_present(conn, "tool_intents", "raw_json")
    add_column_if_missing(conn, "tools", "role", "TEXT")
    add_column_if_missing(conn, "tools", "domain", "TEXT")
    add_column_if_missing(conn, "tools", "intent_elevated", "INTEGER")
    add_column_if_missing(conn, "tool_intents", "atom_id", "INTEGER")
    conn.execute("DELETE FROM _lcm_tools_db_metadata WHERE key = 'intents_document'")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tool_aliases (
            tool_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            alias TEXT NOT NULL,
            PRIMARY KEY (tool_id, position)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tool_parameters (
            tool_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            name TEXT NOT NULL,
            type TEXT,
            mandatory INTEGER NOT NULL DEFAULT 0 CHECK (mandatory IN (0, 1)),
            default_value TEXT,
            default_kind TEXT NOT NULL DEFAULT 'null' CHECK (default_kind IN ('null', 'text', 'bool', 'int', 'real')),
            description TEXT,
            PRIMARY KEY (tool_id, position)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tool_dependencies (
            tool_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            dependency TEXT NOT NULL,
            PRIMARY KEY (tool_id, position)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS intent_parameters (
            intent_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            name TEXT NOT NULL,
            value TEXT,
            value_kind TEXT NOT NULL DEFAULT 'text' CHECK (value_kind IN ('null', 'text', 'bool', 'int', 'real')),
            PRIMARY KEY (intent_id, position)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS atoms (
            atom_id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_path TEXT NOT NULL,
            entry_point TEXT,
            tool_id INTEGER NOT NULL,
            elevated INTEGER NOT NULL DEFAULT 0 CHECK (elevated IN (0, 1)),
            required_switch TEXT,
            runtime_key TEXT,
            archived_at TEXT,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    conn.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_atoms_script_entry ON atoms(script_path, COALESCE(entry_point, ''))"
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS atom_permissions (
            tool_id INTEGER NOT NULL,
            atom_id INTEGER NOT NULL,
            PRIMARY KEY (tool_id, atom_id)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS atom_calls (
            caller_tool_id INTEGER NOT NULL,
            atom_id INTEGER NOT NULL,
            source_path TEXT NOT NULL,
            source_line INTEGER NOT NULL,
            PRIMARY KEY (caller_tool_id, atom_id, source_path, source_line)
        )
        """
    )
    conn.execute(
        """
        CREATE VIEW IF NOT EXISTS v_atoms AS
        SELECT a.atom_id, a.script_path, a.entry_point, a.elevated, a.required_switch, a.runtime_key, a.archived_at,
               t.relative_path AS owning_tool, t.admin AS tool_level,
               CASE t.admin WHEN 0 THEN 'TBD' WHEN 1 THEN 'granted' WHEN 2 THEN 'controlled' WHEN 3 THEN 'admin'
                    ELSE 'TBD' END AS tool_level_text,
               (SELECT group_concat(i.intent_key, ', ') FROM tool_intents i WHERE i.atom_id = a.atom_id) AS intent_keys,
               (SELECT group_concat(pt.relative_path, ', ') FROM atom_permissions p JOIN tools pt ON pt.id = p.tool_id
                 WHERE p.atom_id = a.atom_id) AS permitted_callers,
               CASE WHEN a.elevated = 1 AND t.admin <> 3 THEN 1 ELSE 0 END AS conflict
        FROM atoms a LEFT JOIN tools t ON t.id = a.tool_id
        """
    )
    conn.commit()


def norm_path(value):
    text = str(value or "").strip().replace("\\", "/")
    while text.startswith("./"):
        text = text[2:]
    return text.lower()


def encode_scalar(value):
    """(text, kind) for a scalar parameter value; kinds keep bool / int / real / null apart from text."""
    if value is None:
        return None, "null"
    if isinstance(value, bool):
        return ("1" if value else "0"), "bool"
    if isinstance(value, int):
        return str(value), "int"
    if isinstance(value, float):
        return repr(value), "real"
    return str(value), "text"


def decode_scalar(text, kind):
    if kind == "null":
        return None
    if kind == "bool":
        return text == "1"
    if kind == "int":
        return int(text)
    if kind == "real":
        return float(text)
    return text


def as_list(value):
    """Aliases / Dependencies arrive as null, a single string or a list (PowerShell serialization)."""
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v) for v in value]
    return [str(value)]


def write_tools(conn, tools_list, now_iso):
    cursor = conn.cursor()
    for table in ("tools", "tool_aliases", "tool_parameters", "tool_dependencies", "tool_atom_permissions"):
        cursor.execute(f"DELETE FROM {table}")
    for t in tools_list:
        name = t.get("Name", "")
        intent_elevated = t.get("IntentElevated")
        cursor.execute(
            """
            INSERT INTO tools (
                name, short_name, subsystem, category, audience,
                admin, no_exit, type, description, example,
                relative_path, parameters_json, dependencies_json, created_at, updated_at,
                role, domain, intent_elevated
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?, ?)
            """,
            (
                name,
                t.get("ShortName") or name,
                t.get("SubSystem") or t.get("Subsystem") or t.get("Group") or "LCM",
                t.get("Category") or "Utility",
                t.get("Audience") or "User",
                admin_level(t.get("Admin")),  # CRP-343
                1 if t.get("NoExit") is True else 0,
                t.get("Type") or "PowerShell",
                t.get("Description") or "",
                t.get("Example") or "",
                t.get("RelativePath") or "",
                now_iso, now_iso,
                t.get("Role"),
                t.get("Domain"),
                None if intent_elevated is None else (1 if intent_elevated is True else 0),
            ),
        )
        tool_id = cursor.lastrowid
        for pos, alias in enumerate(as_list(t.get("Aliases"))):
            cursor.execute("INSERT INTO tool_aliases (tool_id, position, alias) VALUES (?, ?, ?)", (tool_id, pos, alias))
        for pos, dep in enumerate(as_list(t.get("Dependencies"))):
            cursor.execute("INSERT INTO tool_dependencies (tool_id, position, dependency) VALUES (?, ?, ?)",
                           (tool_id, pos, dep))
        for pos, prm in enumerate(t.get("Parameters") or []):
            default_text, default_kind = encode_scalar(prm.get("Default"))
            cursor.execute(
                "INSERT INTO tool_parameters (tool_id, position, name, type, mandatory, default_value, default_kind, "
                "description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (tool_id, pos, prm.get("Name") or "", prm.get("Type"), 1 if prm.get("Mandatory") is True else 0,
                 default_text, default_kind, prm.get("Description")),
            )
        rel_path = t.get("RelativePath") or ""
        for intent_key in as_list(t.get("AllowedAtoms")):  # CRP-343: elevated atoms a controlled tool may call
            if rel_path and intent_key:
                cursor.execute(
                    "INSERT OR IGNORE INTO tool_atom_permissions (tool_relative_path, intent_key) VALUES (?, ?)",
                    (rel_path, intent_key.lower()),
                )
    return len(tools_list)


def write_intents(conn, intents_doc, now_iso):
    cursor = conn.cursor()
    intents_dict = intents_doc.get("intents", {}) or {}
    for key in ("version", "description", "updated_at"):
        if key in intents_doc:
            cursor.execute(
                "INSERT INTO _lcm_tools_db_metadata (key, value) VALUES (?, ?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                ("intents_" + key, str(intents_doc.get(key) or "")),
            )
    cursor.execute("DELETE FROM tool_intents")
    cursor.execute("DELETE FROM intent_parameters")
    for k, v in intents_dict.items():
        params_val = v.get("parameters") or {}
        cursor.execute(
            """
            INSERT INTO tool_intents (
                intent_key, goal, executable, script, parameters, trampoline,
                elevated, subsystem, category, audience, role,
                call_count, last_called_at, last_duration_ms, total_duration_ms,
                is_primary_intent, updated_at
            ) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                k,
                v.get("goal", ""),
                v.get("executable", ""),
                v.get("script", ""),
                v.get("trampoline"),
                1 if v.get("elevated") is True else 0,
                v.get("subsystem") or v.get("SubSystem") or v.get("group") or "LCM",
                v.get("category", ""),
                v.get("audience", ""),
                v.get("role", ""),
                int(v.get("call_count", 0) or 0),
                v.get("last_called_at"),
                round(float(v.get("last_duration_ms", 0) or 0), 2),
                round(float(v.get("total_duration_ms", 0) or 0), 2),
                1 if v.get("is_primary_intent") is True else 0,
                now_iso,
            ),
        )
        intent_id = cursor.lastrowid
        if isinstance(params_val, dict):
            for pos, (pname, pvalue) in enumerate(params_val.items()):
                text, kind = encode_scalar(pvalue)
                cursor.execute(
                    "INSERT INTO intent_parameters (intent_id, position, name, value, value_kind) VALUES (?, ?, ?, ?, ?)",
                    (intent_id, pos, pname, text, kind),
                )
    return len(intents_dict)


def rebuild_atoms(conn, now_iso):
    """CRP-363: one atom per intent script (entry_point NULL), owned by the tool of the same file; rows are never
    deleted - an atom without a script any more is archived (archived_at)."""
    cursor = conn.cursor()
    tools_by_path = {norm_path(p): i for i, p in cursor.execute("SELECT id, relative_path FROM tools")}
    scripts = {}
    for script, elevated in cursor.execute("SELECT script, elevated FROM tool_intents"):
        key = norm_path(script)
        if key:
            scripts[key] = max(scripts.get(key, 0), int(elevated or 0))
    unowned = []
    seen = set()
    for key, elevated in sorted(scripts.items()):
        tool_id = tools_by_path.get(key)
        if tool_id is None:
            unowned.append(key)
            continue
        runtime_key = "python" if key.endswith(".py") else None
        cursor.execute(
            """
            INSERT INTO atoms (script_path, entry_point, tool_id, elevated, runtime_key, archived_at, updated_at)
            VALUES (?, NULL, ?, ?, ?, NULL, ?)
            ON CONFLICT(script_path, COALESCE(entry_point, '')) DO UPDATE SET
                tool_id = excluded.tool_id, elevated = excluded.elevated, runtime_key = excluded.runtime_key,
                archived_at = NULL, updated_at = excluded.updated_at
            """,
            (key, tool_id, elevated, runtime_key, now_iso),
        )
        seen.add(key)
    for atom_id, script_path, archived_at in cursor.execute(
        "SELECT atom_id, script_path, archived_at FROM atoms WHERE entry_point IS NULL"
    ).fetchall():
        if script_path not in seen and archived_at is None:
            cursor.execute("UPDATE atoms SET archived_at = ?, updated_at = ? WHERE atom_id = ?",
                           (now_iso, now_iso, atom_id))
    atom_by_script = {s: a for a, s in cursor.execute(
        "SELECT atom_id, script_path FROM atoms WHERE entry_point IS NULL")}
    for intent_id, script in cursor.execute("SELECT id, script FROM tool_intents").fetchall():
        cursor.execute("UPDATE tool_intents SET atom_id = ? WHERE id = ?",
                       (atom_by_script.get(norm_path(script)), intent_id))
    cursor.execute("DELETE FROM atom_permissions")
    intent_script = {k.lower(): norm_path(s) for k, s in cursor.execute(
        "SELECT intent_key, script FROM tool_intents")}
    for rel_path, intent_key in cursor.execute(
        "SELECT tool_relative_path, intent_key FROM tool_atom_permissions").fetchall():
        tool_id = tools_by_path.get(norm_path(rel_path))
        atom_id = atom_by_script.get(intent_script.get(str(intent_key).lower(), ""))
        if tool_id is not None and atom_id is not None:
            cursor.execute("INSERT OR IGNORE INTO atom_permissions (tool_id, atom_id) VALUES (?, ?)",
                           (tool_id, atom_id))
    return unowned


BUSY_TIMEOUT_MS = 5000


def open_read(db_path):
    """Read-only connection (mode=ro): a reader never takes a write lock or changes the file."""
    conn = sqlite3.connect(Path(db_path).resolve().as_uri() + "?mode=ro", uri=True, timeout=BUSY_TIMEOUT_MS / 1000)
    conn.execute(f"PRAGMA busy_timeout = {BUSY_TIMEOUT_MS}")
    return conn


def open_store(db_path, workspace_root=None):
    """Write connection with schema setup; used only by import / sync / migrate."""
    conn = sqlite3.connect(db_path, timeout=BUSY_TIMEOUT_MS / 1000)
    conn.execute(f"PRAGMA busy_timeout = {BUSY_TIMEOUT_MS}")
    init_db(conn, workspace_root=workspace_root)
    ensure_store_schema(conn)
    return conn


def import_documents(db_path, tools_list=None, intents_doc=None, workspace_root=None, silent=False,
                     keep_table_statistics=False):
    """CRP-358: the only writer of the tool store; writes the tables and rebuilds the atoms. No SQL dump here:
    tools.sql is written only at publish (operator 2026-11-20)."""
    conn = open_store(db_path, workspace_root)
    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    previous_stats = {}
    if keep_table_statistics:
        previous_stats = {r[0]: r[1:] for r in conn.execute(
            "SELECT intent_key, call_count, last_called_at, last_duration_ms, total_duration_ms FROM tool_intents")}
    tool_count = write_tools(conn, tools_list, now_iso) if tools_list is not None else None
    intent_count = write_intents(conn, intents_doc, now_iso) if intents_doc is not None else None
    for key, (count, last_at, last_ms, total_ms) in previous_stats.items():
        conn.execute(
            "UPDATE tool_intents SET call_count = ?, last_called_at = ?, last_duration_ms = ?, total_duration_ms = ? "
            "WHERE intent_key = ?",
            (count, last_at or None, last_ms, total_ms, key),
        )
    unowned = rebuild_atoms(conn, now_iso)
    conn.commit()
    conn.close()
    if not silent:
        print(f"[STORE] tools={tool_count} intents={intent_count} unowned_scripts={len(unowned)} -> {db_path}")
        for key in unowned:
            print(f"[WARN] intent script without a tools row: {key}")


def list_by_owner(conn, query):
    grouped = {}
    for owner, value in conn.execute(query):
        grouped.setdefault(owner, []).append(value)
    return grouped


def export_catalog(db_path):
    conn = open_read(db_path)
    aliases = list_by_owner(conn, "SELECT tool_id, alias FROM tool_aliases ORDER BY tool_id, position")
    deps = list_by_owner(conn, "SELECT tool_id, dependency FROM tool_dependencies ORDER BY tool_id, position")
    params = {}
    for tool_id, name, ptype, mandatory, dval, dkind, desc in conn.execute(
        "SELECT tool_id, name, type, mandatory, default_value, default_kind, description FROM tool_parameters "
        "ORDER BY tool_id, position"
    ):
        params.setdefault(tool_id, []).append({
            "Name": name, "Type": ptype, "Mandatory": mandatory == 1,
            "Default": decode_scalar(dval, dkind), "Description": desc,
        })
    allowed = list_by_owner(conn, "SELECT tool_relative_path, intent_key FROM tool_atom_permissions ORDER BY id")
    rows = []
    for (tool_id, name, short_name, subsystem, category, audience, admin, no_exit, tool_type, description, example,
         rel_path, role, domain, intent_elevated) in conn.execute(
        "SELECT id, name, short_name, subsystem, category, audience, admin, no_exit, type, description, example, "
        "relative_path, role, domain, intent_elevated FROM tools ORDER BY id ASC"
    ):
        rows.append({
            "Name": name,
            "ShortName": short_name,
            "Aliases": aliases.get(tool_id) or None,
            "Role": role,
            "Audience": audience,
            "Admin": admin,
            "AllowedAtoms": allowed.get(rel_path) or None,
            "NoExit": no_exit == 1,
            "Group": subsystem,
            "Domain": domain,
            "Type": tool_type,
            "Category": category,
            "Description": description,
            "Example": example,
            "RelativePath": rel_path,
            "Parameters": params.get(tool_id, []),
            "Dependencies": deps.get(tool_id) or None,
            "IntentElevated": None if intent_elevated is None else intent_elevated == 1,
        })
    conn.close()
    return rows


def export_intents(db_path):
    conn = open_read(db_path)
    meta = dict(conn.execute("SELECT key, value FROM _lcm_tools_db_metadata WHERE key LIKE 'intents_%'"))
    params = {}
    for intent_id, name, value, kind in conn.execute(
        "SELECT intent_id, name, value, value_kind FROM intent_parameters ORDER BY intent_id, position"
    ):
        params.setdefault(intent_id, {})[name] = decode_scalar(value, kind)
    intents = {}
    for (intent_id, key, goal, executable, script, trampoline, elevated, subsystem, category, audience, role,
         count, last_at, last_ms, total_ms, primary) in conn.execute(
        "SELECT id, intent_key, goal, executable, script, trampoline, elevated, subsystem, category, audience, role, "
        "call_count, last_called_at, last_duration_ms, total_duration_ms, is_primary_intent "
        "FROM tool_intents ORDER BY id ASC"
    ):
        intents[key] = {
            "goal": goal, "executable": executable, "script": script, "parameters": params.get(intent_id, {}),
            "trampoline": trampoline, "elevated": elevated == 1, "group": subsystem, "category": category,
            "audience": audience, "role": role, "call_count": count, "last_called_at": last_at or None,
            "last_duration_ms": float(last_ms or 0), "total_duration_ms": float(total_ms or 0),
            "is_primary_intent": primary == 1,
        }
    conn.close()
    return {
        "version": meta.get("intents_version", "1.0.0"),
        "description": meta.get("intents_description", ""),
        "total_intents": len(intents),
        "updated_at": meta.get("intents_updated_at", ""),
        "intents": intents,
    }


def record_call(db_path, target, duration_ms, timestamp):
    """CRP-358 (replaces the JSON writer of Update-LcmToolIntentCall): intent call statistics in the table."""
    clean = (target or "").strip()
    if not clean:
        return 0
    name = os.path.basename(clean.replace("\\", "/"))
    match = re.search(r"(?i)([A-Za-z0-9_\-\.]+\.(?:ps1|cmd|bat|py))", clean)
    if match:
        name = match.group(1)
    conn = sqlite3.connect(db_path, timeout=BUSY_TIMEOUT_MS / 1000)  # statistics only, no schema setup
    conn.execute(f"PRAGMA busy_timeout = {BUSY_TIMEOUT_MS}")
    updated = 0
    for intent_id, key, script, trampoline in conn.execute(
        "SELECT id, intent_key, script, trampoline FROM tool_intents").fetchall():
        script_l = (script or "").lower()
        hit = key.lower() in (clean.lower(), name.lower()) or \
            (script_l and (name.lower() in script_l or clean.lower() in script_l)) or \
            ((trampoline or "").lower() in (name.lower(), clean.lower()) and bool(trampoline))
        if hit:
            conn.execute(
                "UPDATE tool_intents SET call_count = call_count + 1, last_called_at = ?, last_duration_ms = ?, "
                "total_duration_ms = total_duration_ms + ? WHERE id = ?",
                (timestamp, round(duration_ms, 2), round(duration_ms, 2), intent_id),
            )
            updated += 1
    conn.commit()
    conn.close()
    return updated


def verify_store(db_path):
    """CRP-358: integrity of the tool store: every intent script has an atom, no elevated atom below tool level 3,
    no orphaned child rows."""
    conn = open_read(db_path)
    checks = {
        "intents without atom": "SELECT COUNT(*) FROM tool_intents WHERE atom_id IS NULL AND COALESCE(script, '') <> ''",
        "atom conflicts": "SELECT COUNT(*) FROM v_atoms WHERE conflict = 1 AND archived_at IS NULL",
        "orphaned tool child rows": "SELECT (SELECT COUNT(*) FROM tool_aliases WHERE tool_id NOT IN (SELECT id FROM tools))"
                                    " + (SELECT COUNT(*) FROM tool_parameters WHERE tool_id NOT IN (SELECT id FROM tools))"
                                    " + (SELECT COUNT(*) FROM tool_dependencies WHERE tool_id NOT IN (SELECT id FROM tools))",
        "orphaned intent parameters": "SELECT COUNT(*) FROM intent_parameters WHERE intent_id NOT IN "
                                      "(SELECT id FROM tool_intents)",
    }
    failed = 0
    for label, query in checks.items():
        count = conn.execute(query).fetchone()[0]
        state = "PASS" if count == 0 else "FAIL"
        failed += 0 if count == 0 else 1
        print(f"[{state}] {label}: {count}")
    tools_n = conn.execute("SELECT COUNT(*) FROM tools").fetchone()[0]
    intents_n = conn.execute("SELECT COUNT(*) FROM tool_intents").fetchone()[0]
    atoms_n = conn.execute("SELECT COUNT(*) FROM atoms WHERE archived_at IS NULL").fetchone()[0]
    conn.close()
    print(f"[INFO] tools={tools_n} intents={intents_n} atoms={atoms_n}")
    return 1 if failed else 0


def sql_literal(val):
    if val is None:
        return "NULL"
    if isinstance(val, (int, float)):
        return str(val)
    return "'" + str(val).replace("'", "''") + "'"


def dump_db_to_sql(db_path, sql_path, silent=False):
    """Publish-only projection of tools.db (operator 2026-11-20): written by the push so the pushed state can be
    rebuilt from the remote; no other use. Schema and rows of every table, views and indexes."""
    conn = open_read(db_path)
    lines = [
        "-- LCM Tools store: publish projection (rebuild tools.db from the remote; no other use)",
        f"-- Generated at: {datetime.now().isoformat()}",
        "-- Schema standard: docs/DataDesign-Tools.md",
        "",
        "PRAGMA foreign_keys=OFF;",
        "BEGIN TRANSACTION;",
        "",
    ]
    objects = conn.execute(
        "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
        "ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END, name"
    ).fetchall()
    for obj_type, name, sql in objects:
        lines.append(f"-- {obj_type}: {name}")
        lines.append(sql.replace("CREATE TABLE ", "CREATE TABLE IF NOT EXISTS ", 1)
                     .replace("CREATE INDEX ", "CREATE INDEX IF NOT EXISTS ", 1)
                     .replace("CREATE UNIQUE INDEX ", "CREATE UNIQUE INDEX IF NOT EXISTS ", 1)
                     .replace("CREATE VIEW ", "CREATE VIEW IF NOT EXISTS ", 1) + ";")
        if obj_type == "table":
            cols = column_names(conn, name)
            col_list = ", ".join(cols)
            for row in conn.execute(f"SELECT {col_list} FROM {name} ORDER BY rowid ASC"):
                lines.append(f"INSERT OR REPLACE INTO {name} ({col_list}) VALUES ("
                             + ", ".join(sql_literal(v) for v in row) + ");")
        lines.append("")
    lines.append("COMMIT;")
    lines.append("")
    conn.close()
    with open(sql_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    if not silent:
        print(f"[DUMP] Publish projection written to {sql_path}")


def restore_from_sql(sql_path, db_path, silent=False):
    """Rebuilds tools.db from the publish projection tools.sql (after a pull or on a fresh clone): builds a new
    database next to the target, checks it, then replaces the target atomically; the previous file is kept as
    <db>.before-restore."""
    if not os.path.exists(sql_path):
        raise FileNotFoundError(f"Publish projection not found: {sql_path}")
    with open(sql_path, "r", encoding="utf-8") as f:
        script = f.read()
    temp_path = db_path + ".restore-tmp"
    if os.path.exists(temp_path):
        os.remove(temp_path)
    conn = sqlite3.connect(temp_path)
    conn.executescript(script)
    tools_n = conn.execute("SELECT COUNT(*) FROM tools").fetchone()[0]
    intents_n = conn.execute("SELECT COUNT(*) FROM tool_intents").fetchone()[0]
    conn.close()
    if tools_n == 0:
        os.remove(temp_path)
        raise ValueError("restore refused: the projection holds no tools")
    if os.path.exists(db_path):
        os.replace(db_path, db_path + ".before-restore")
    os.replace(temp_path, db_path)
    if not silent:
        print(f"[RESTORE] tools={tools_n} intents={intents_n} from {sql_path} -> {db_path}")


def migrate_from_json(json_dir, db_path, workspace_root):
    """CRP-358 one-time reconciliation from retained JSON copies (table wins for statistics, operator 2026-11-19)."""
    with open(os.path.join(json_dir, "tool_catalog.json"), "r", encoding="utf-8") as f:
        tools_list = json.load(f)
    with open(os.path.join(json_dir, "tool_intents.json"), "r", encoding="utf-8") as f:
        intents_doc = json.load(f)
    import_documents(db_path, tools_list, intents_doc, workspace_root, keep_table_statistics=True)


def main():
    parser = argparse.ArgumentParser(description="LCM Tools SQLite store (CRP-358: the tables are the only store)")
    parser.add_argument("--action", choices=["sync", "dump", "restore", "verify", "export", "import", "record-call", "migrate"],
                        default="sync")
    parser.add_argument("--store", choices=["catalog", "intents"], help="export / import: which document")
    parser.add_argument("--target", help="record-call: command or path that was run")
    parser.add_argument("--duration-ms", type=float, default=0.0)
    parser.add_argument("--timestamp", default="")
    parser.add_argument("--json-dir", help="migrate: folder with the retained tool_catalog.json / tool_intents.json")
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args()

    _, _, default_db, sql_path, ws_root = get_default_paths()
    db_path = resolve_db_path(default_db)

    if args.action == "sync":
        # schema and atoms from the tables; no SQL dump (publish only)
        conn = open_store(db_path, ws_root)
        rebuild_atoms(conn, datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        conn.commit()
        conn.close()
    elif args.action == "dump":
        if db_path != default_db:
            sys.exit("dump refused: an isolated store never writes the publish projection")
        dump_db_to_sql(db_path, sql_path, silent=args.silent)
    elif args.action == "restore":
        restore_from_sql(sql_path, db_path, silent=args.silent)
    elif args.action == "verify":
        sys.exit(verify_store(db_path))
    elif args.action == "export":
        doc = export_catalog(db_path) if args.store == "catalog" else export_intents(db_path)
        sys.stdout.write(json.dumps(doc, ensure_ascii=False, indent=2))
    elif args.action == "import":
        doc = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
        if args.store == "catalog":
            import_documents(db_path, tools_list=doc, workspace_root=ws_root, silent=args.silent)
        else:
            import_documents(db_path, intents_doc=doc, workspace_root=ws_root, silent=args.silent)
    elif args.action == "record-call":
        stamp = args.timestamp or datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        print(record_call(db_path, args.target, args.duration_ms, stamp))
    elif args.action == "migrate":
        if not args.json_dir:
            sys.exit("migrate needs --json-dir")
        migrate_from_json(args.json_dir, db_path, ws_root)


if __name__ == "__main__":
    main()
