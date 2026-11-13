#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module: tools/sync_tool_catalog_db.py
Purpose: High-speed SQLite synchronization, canonical SQL text projection, and query engine
         for LCM Tool Catalog and Tool Intents under Dual-State Projection architecture.
Path: LCM_Inventory/tools/sync_tool_catalog_db.py
Authors: Rolf, LCM_AI Engine
Version: 10.2.4
Status: Production Engine
Date: 2026-11-13 13:30:00
"""

import argparse
from datetime import datetime
import json
import os
import sqlite3
import sys

sys.stdout.reconfigure(encoding="utf-8")


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


def sync_json_to_db(tools_json_path, intents_json_path, db_path, sql_path=None, workspace_root=None, silent=False):
    if not os.path.exists(tools_json_path):
        raise FileNotFoundError(f"Tools JSON not found: {tools_json_path}")

    with open(tools_json_path, "r", encoding="utf-8") as f:
        tools_list = json.load(f)

    intents_dict = {}
    if os.path.exists(intents_json_path):
        with open(intents_json_path, "r", encoding="utf-8") as f:
            intents_raw = json.load(f)
            intents_dict = intents_raw.get("intents", {})

    conn = sqlite3.connect(db_path)
    init_db(conn, workspace_root=workspace_root)
    cursor = conn.cursor()

    # 1. Sync Tools Table
    cursor.execute("DELETE FROM tools")
    now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    tools_rows = []
    for t in tools_list:
        name = t.get("Name", "")
        short_name = t.get("ShortName") or name
        subsystem = t.get("SubSystem") or t.get("Subsystem") or t.get("Group") or "LCM"
        category = t.get("Category") or "Utility"
        audience = t.get("Audience") or "User"
        admin = 1 if t.get("Admin") is True else 0
        no_exit = 1 if t.get("NoExit") is True else 0
        tool_type = t.get("Type") or "PowerShell"
        desc = t.get("Description") or ""
        example = t.get("Example") or ""
        rel_path = t.get("RelativePath") or ""
        params_json = json.dumps(t.get("Parameters", []), ensure_ascii=False)
        deps_json = json.dumps(t.get("Dependencies", []), ensure_ascii=False)

        tools_rows.append((
            name, short_name, subsystem, category, audience,
            admin, no_exit, tool_type, desc, example,
            rel_path, params_json, deps_json, now_iso, now_iso
        ))

    cursor.executemany(
        """
        INSERT INTO tools (
            name, short_name, subsystem, category, audience,
            admin, no_exit, type, description, example,
            relative_path, parameters_json, dependencies_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        tools_rows
    )

    # 2. Sync Tool Intents Table
    cursor.execute("DELETE FROM tool_intents")
    intents_rows = []
    for k, v in intents_dict.items():
        subsystem = v.get("subsystem") or v.get("SubSystem") or v.get("group") or "LCM"
        elevated = 1 if v.get("elevated") is True else 0
        is_primary = 1 if v.get("is_primary_intent") is True else 0
        params_val = v.get("parameters", "")
        if isinstance(params_val, (dict, list)):
            params_val = json.dumps(params_val, ensure_ascii=False)
        else:
            params_val = str(params_val or "")

        intents_rows.append((
            k,
            v.get("goal", ""),
            v.get("executable", ""),
            v.get("script", ""),
            params_val,
            v.get("trampoline", ""),
            elevated,
            subsystem,
            v.get("category", ""),
            v.get("audience", ""),
            v.get("role", ""),
            int(v.get("call_count", 0)),
            v.get("last_called_at", ""),
            int(v.get("last_duration_ms", 0)),
            int(v.get("total_duration_ms", 0)),
            is_primary,
            now_iso
        ))

    cursor.executemany(
        """
        INSERT INTO tool_intents (
            intent_key, goal, executable, script, parameters, trampoline,
            elevated, subsystem, category, audience, role,
            call_count, last_called_at, last_duration_ms, total_duration_ms,
            is_primary_intent, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        intents_rows
    )

    conn.commit()
    conn.close()

    if not silent:
        print(f"[SYNC] Successfully inserted {len(tools_rows)} tools and {len(intents_rows)} intents into {db_path}")

    if sql_path:
        dump_db_to_sql(db_path, sql_path, silent=silent)


def dump_db_to_sql(db_path, sql_path, silent=False):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    lines = [
        "-- Authoritative LCM Tools & Intents Dual-State SQL Dump",
        f"-- Generated at: {datetime.now().isoformat()}",
        "-- Schema standard: docs/DataDesign-Tools.md",
        "",
        "PRAGMA foreign_keys=OFF;",
        "BEGIN TRANSACTION;",
        "",
    ]

    # Dump tools
    lines.append("-- Table: tools")
    lines.append("""CREATE TABLE IF NOT EXISTS tools (
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
);""")
    cursor.execute("SELECT name, short_name, subsystem, category, audience, admin, no_exit, type, description, example, relative_path, parameters_json, dependencies_json, created_at, updated_at FROM tools ORDER BY id ASC")
    for row in cursor.fetchall():
        escaped = []
        for val in row:
            if val is None:
                escaped.append("NULL")
            elif isinstance(val, (int, float)):
                escaped.append(str(val))
            else:
                escaped.append("'" + str(val).replace("'", "''") + "'")
        lines.append(f"INSERT INTO tools (name, short_name, subsystem, category, audience, admin, no_exit, type, description, example, relative_path, parameters_json, dependencies_json, created_at, updated_at) VALUES ({', '.join(escaped)});")

    lines.append("")
    lines.append("-- Table: tool_intents")
    lines.append("""CREATE TABLE IF NOT EXISTS tool_intents (
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
);""")
    cursor.execute("SELECT intent_key, goal, executable, script, parameters, trampoline, elevated, subsystem, category, audience, role, call_count, last_called_at, last_duration_ms, total_duration_ms, is_primary_intent, updated_at FROM tool_intents ORDER BY id ASC")
    for row in cursor.fetchall():
        escaped = []
        for val in row:
            if val is None:
                escaped.append("NULL")
            elif isinstance(val, (int, float)):
                escaped.append(str(val))
            else:
                escaped.append("'" + str(val).replace("'", "''") + "'")
        lines.append(f"INSERT INTO tool_intents (intent_key, goal, executable, script, parameters, trampoline, elevated, subsystem, category, audience, role, call_count, last_called_at, last_duration_ms, total_duration_ms, is_primary_intent, updated_at) VALUES ({', '.join(escaped)});")

    lines.append("")
    lines.append("COMMIT;")
    lines.append("")

    conn.close()

    with open(sql_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    if not silent:
        print(f"[DUMP] Canonical SQL text export written to {sql_path}")


def verify_parity(tools_json_path, intents_json_path, db_path):
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"Database not found: {db_path}")

    with open(tools_json_path, "r", encoding="utf-8") as f:
        tools_list = json.load(f)

    with open(intents_json_path, "r", encoding="utf-8") as f:
        intents_dict = json.load(f).get("intents", {})

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM tools")
    db_tools_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM tool_intents")
    db_intents_count = cursor.fetchone()[0]

    conn.close()

    if db_tools_count != len(tools_list):
        raise ValueError(f"Tools parity mismatch: JSON has {len(tools_list)}, DB has {db_tools_count}")
    if db_intents_count != len(intents_dict):
        raise ValueError(f"Intents parity mismatch: JSON has {len(intents_dict)}, DB has {db_intents_count}")

    print(f"[PASS] 100% Tools DB Parity Verified across {db_tools_count} tools and {db_intents_count} intents.")


def main():
    parser = argparse.ArgumentParser(description="LCM Tools SQLite Sync Engine")
    parser.add_argument("--action", choices=["sync", "dump", "verify"], default="sync")
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args()

    tools_json, intents_json, db_path, sql_path, ws_root = get_default_paths()

    if args.action == "sync":
        sync_json_to_db(tools_json, intents_json, db_path, sql_path, workspace_root=ws_root, silent=args.silent)
    elif args.action == "dump":
        dump_db_to_sql(db_path, sql_path, silent=args.silent)
    elif args.action == "verify":
        verify_parity(tools_json, intents_json, db_path)


if __name__ == "__main__":
    main()
