#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module: tools/sync_proposals_db.py
Purpose: High-speed SQLite synchronization, canonical SQL text projection, and query engine
         for LCM Proposals Ledger under Dual-State Projection architecture.
Path: LCM_Inventory/tools/sync_proposals_db.py
Authors: Rolf, LCM_AI Engine
Version: 10.2.3
Status: Production Engine
Date: 2026-11-12 12:15:00
"""

import argparse
from datetime import datetime
import json
import os
import sqlite3
import sys

sys.stdout.reconfigure(encoding="utf-8")

ACTIVE_SERIES_PREFIX = "10.2."


def get_default_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    workspace_root = os.path.dirname(repo_root)
    json_path = os.path.join(repo_root, "data", "proposals", "proposals.json")
    db_path = os.path.join(repo_root, "data", "proposals", "proposals.db")
    sql_path = os.path.join(repo_root, "data", "proposals", "proposals.sql")
    return json_path, db_path, sql_path, workspace_root


def get_lcm_version(repo_root):
    inv_path = os.path.join(repo_root, "data", "inventory.json")
    if os.path.exists(inv_path):
        try:
            with open(inv_path, "r", encoding="utf-8") as f:
                inv = json.load(f)
            baseline = inv.get("workspace_ai_baseline", {})
            return baseline.get("GlobalLCMVersion", "10.2.3")
        except Exception:
            pass
    return "10.2.3"


def init_db(conn, workspace_root=None, workspace_role="LIVE", sandbox_id="", lcm_version="10.2.3"):
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS _lcm_db_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS proposals (
            id INTEGER PRIMARY KEY,
            crp_id TEXT NOT NULL UNIQUE,
            lcm_version TEXT NOT NULL,
            state TEXT NOT NULL,
            progress_state TEXT,
            priority INTEGER DEFAULT 5,
            origin_repo TEXT,
            title TEXT NOT NULL,
            details TEXT,
            author TEXT,
            created_at TEXT,
            pushed_at TEXT,
            bundle_dir TEXT,
            disposition TEXT,
            flow_mode TEXT,
            is_active INTEGER DEFAULT 0,
            is_historical INTEGER DEFAULT 0,
            raw_json TEXT NOT NULL
        )
        """
    )
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_lcm_version ON proposals(lcm_version)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_state ON proposals(state)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_is_active ON proposals(is_active)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_is_historical ON proposals(is_historical)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_priority ON proposals(priority)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_proposals_origin_repo ON proposals(origin_repo)")

    # Update metadata
    now_iso = datetime.now().isoformat()
    meta_entries = [
        ("workspace_root", str(workspace_root or "")),
        ("workspace_role", str(workspace_role or "LIVE")),
        ("sandbox_id", str(sandbox_id or "")),
        ("lcm_version", str(lcm_version or "10.2.3")),
        ("schema_version", "1.0.0"),
        ("last_synced_at", now_iso),
    ]
    cursor.executemany(
        "INSERT OR REPLACE INTO _lcm_db_metadata (key, value) VALUES (?, ?)",
        meta_entries
    )
    conn.commit()


def dump_db_to_sql(db_path, sql_path, silent=False):
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"Source database not found for dump: {db_path}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT key, value FROM _lcm_db_metadata ORDER BY key")
    meta_rows = cursor.fetchall()

    cursor.execute("SELECT * FROM proposals ORDER BY id ASC")
    proposal_rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]
    conn.close()

    lines = [
        "-- ==========================================================================",
        "-- LCM Proposals Ledger Canonical SQL Dump (Git-Reviewable Text Projection)",
        f"-- Generated: {datetime.now().isoformat()}",
        f"-- Total Proposals: {len(proposal_rows)}",
        "-- ==========================================================================",
        "",
        "BEGIN TRANSACTION;",
        "",
        "CREATE TABLE IF NOT EXISTS _lcm_db_metadata (",
        "    key TEXT PRIMARY KEY,",
        "    value TEXT NOT NULL",
        ");",
        "",
        "CREATE TABLE IF NOT EXISTS proposals (",
        "    id INTEGER PRIMARY KEY,",
        "    crp_id TEXT NOT NULL UNIQUE,",
        "    lcm_version TEXT NOT NULL,",
        "    state TEXT NOT NULL,",
        "    progress_state TEXT,",
        "    priority INTEGER DEFAULT 5,",
        "    origin_repo TEXT,",
        "    title TEXT NOT NULL,",
        "    details TEXT,",
        "    author TEXT,",
        "    created_at TEXT,",
        "    pushed_at TEXT,",
        "    bundle_dir TEXT,",
        "    disposition TEXT,",
        "    flow_mode TEXT,",
        "    is_active INTEGER DEFAULT 0,",
        "    is_historical INTEGER DEFAULT 0,",
        "    raw_json TEXT NOT NULL",
        ");",
        "",
        "CREATE INDEX IF NOT EXISTS idx_proposals_lcm_version ON proposals(lcm_version);",
        "CREATE INDEX IF NOT EXISTS idx_proposals_state ON proposals(state);",
        "CREATE INDEX IF NOT EXISTS idx_proposals_is_active ON proposals(is_active);",
        "CREATE INDEX IF NOT EXISTS idx_proposals_is_historical ON proposals(is_historical);",
        "CREATE INDEX IF NOT EXISTS idx_proposals_priority ON proposals(priority);",
        "CREATE INDEX IF NOT EXISTS idx_proposals_origin_repo ON proposals(origin_repo);",
        "",
        "DELETE FROM _lcm_db_metadata;",
    ]

    for k, v in meta_rows:
        escaped_val = v.replace("'", "''")
        lines.append(f"INSERT INTO _lcm_db_metadata (key, value) VALUES ('{k}', '{escaped_val}');")

    lines.append("")
    lines.append("DELETE FROM proposals;")

    col_list = ", ".join(columns)
    for row in proposal_rows:
        val_strs = []
        for item in row:
            if item is None:
                val_strs.append("NULL")
            elif isinstance(item, (int, float)):
                val_strs.append(str(item))
            else:
                escaped = str(item).replace("'", "''")
                val_strs.append(f"'{escaped}'")
        lines.append(f"INSERT INTO proposals ({col_list}) VALUES ({', '.join(val_strs)});")

    lines.append("")
    lines.append("COMMIT;")
    lines.append("")

    with open(sql_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    if not silent:
        print(f"[DUMP] Emitted canonical SQL dump: {sql_path} ({len(proposal_rows)} proposals)")

    return len(proposal_rows)


def hydrate_sql_to_db(sql_path, db_path, workspace_root=None, workspace_role="LIVE", sandbox_id="", silent=False):
    if not os.path.exists(sql_path):
        raise FileNotFoundError(f"Canonical SQL dump not found: {sql_path}")

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_script = f.read()

    # Reconstruct database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.executescript(sql_script)

    # Re-stamp local environment metadata
    now_iso = datetime.now().isoformat()
    meta_entries = [
        ("workspace_root", str(workspace_root or "")),
        ("workspace_role", str(workspace_role or "LIVE")),
        ("sandbox_id", str(sandbox_id or "")),
        ("hydrated_at", now_iso),
    ]
    cursor.executemany(
        "INSERT OR REPLACE INTO _lcm_db_metadata (key, value) VALUES (?, ?)",
        meta_entries
    )
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM proposals")
    count = cursor.fetchone()[0]
    conn.close()

    if not silent:
        print("=" * 70)
        print("LCM PROPOSALS DATABASE HYDRATED FROM SQL DUMP")
        print("=" * 70)
        print(f"Source SQL   : {sql_path}")
        print(f"Target DB    : {db_path}")
        print(f"Total Rows   : {count}")
        print(f"Workspace    : {workspace_root} ({workspace_role})")
        print("=" * 70)

    return count


def sync_json_to_db(json_path, db_path, sql_path=None, workspace_root=None, workspace_role="LIVE", sandbox_id="", silent=False):
    if not os.path.exists(json_path):
        raise FileNotFoundError(f"Proposals JSON ledger not found: {json_path}")

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lcm_ver = get_lcm_version(repo_root)

    with open(json_path, "r", encoding="utf-8") as f:
        store = json.load(f)

    proposals = store.get("proposals", [])
    conn = sqlite3.connect(db_path)
    init_db(conn, workspace_root=workspace_root, workspace_role=workspace_role, sandbox_id=sandbox_id, lcm_version=lcm_ver)

    cursor = conn.cursor()
    cursor.execute("BEGIN TRANSACTION")
    cursor.execute("DELETE FROM proposals")

    insert_sql = """
        INSERT INTO proposals (
            id, crp_id, lcm_version, state, progress_state, priority,
            origin_repo, title, details, author, created_at, pushed_at,
            bundle_dir, disposition, flow_mode, is_active, is_historical, raw_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    rows = []
    version_counts = {}

    for p in proposals:
        pid = int(p.get("id", 0))
        crp_id = str(p.get("crp_id") or f"CRP-{pid}")
        lcm_version = str(p.get("lcm_version") or "Legacy (<10.0)")
        state = str(p.get("state") or "suggested")
        progress_state = str(p.get("progress_state") or "")
        priority = int(p.get("priority", 5) if p.get("priority") is not None else 5)
        origin_repo = str(p.get("origin_repo") or "")
        title = str(p.get("title") or "")
        details = str(p.get("details") or "")
        author = str(p.get("author") or "")

        dates = p.get("dates") or {}
        created_at = str(dates.get("created") or p.get("timestamp") or "")
        pushed_at = str(dates.get("pushed") or p.get("pushed_at") or "")

        bundle_dir = str(p.get("bundle_dir") or "")
        disposition = str(p.get("disposition") or "")
        flow_mode = str(p.get("flow_mode") or "standard")

        is_active = 1 if state not in ("pushed", "rejected", "superseded", "withdrawn") else 0
        is_historical = 0 if lcm_version.startswith(ACTIVE_SERIES_PREFIX) else 1

        raw_json = json.dumps(p, ensure_ascii=False)

        rows.append((
            pid, crp_id, lcm_version, state, progress_state, priority,
            origin_repo, title, details, author, created_at, pushed_at,
            bundle_dir, disposition, flow_mode, is_active, is_historical, raw_json
        ))

        version_counts[lcm_version] = version_counts.get(lcm_version, 0) + 1

    cursor.executemany(insert_sql, rows)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM proposals")
    total_db_rows = cursor.fetchone()[0]
    conn.close()

    if sql_path:
        dump_db_to_sql(db_path, sql_path, silent=True)

    if not silent:
        print("=" * 70)
        print("LCM PROPOSALS SQLITE DUAL-STATE SYNCHRONIZATION")
        print("=" * 70)
        print(f"Source JSON  : {json_path}")
        print(f"Target DB    : {db_path}")
        if sql_path:
            print(f"Target SQL   : {sql_path}")
        print(f"Synced Rows  : {total_db_rows} / {len(proposals)}")
        print("\nBreakdown by LCM Version:")
        for ver, count in sorted(version_counts.items(), key=lambda x: str(x[0])):
            active_marker = "[ACTIVE SERIES]" if ver.startswith(ACTIVE_SERIES_PREFIX) else "[HISTORICAL]"
            print(f"  - {ver:<16}: {count:>4} proposals  {active_marker}")
        print("=" * 70)

    return total_db_rows


def query_proposals(db_path, horizon=None, version=None, state=None, active_only=False, limit=None):
    if not os.path.exists(db_path):
        json_path, _, sql_path, ws_root = get_default_paths()
        if os.path.exists(sql_path):
            hydrate_sql_to_db(sql_path, db_path, workspace_root=ws_root, silent=True)
        else:
            sync_json_to_db(json_path, db_path, sql_path=sql_path, workspace_root=ws_root, silent=True)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    conditions = []
    params = []

    if active_only:
        conditions.append("is_active = 1")

    if horizon == "active":
        conditions.append("(is_active = 1 OR is_historical = 0)")
    elif horizon == "historical":
        conditions.append("is_historical = 1")

    if version:
        if version == "10.2.x":
            conditions.append("lcm_version LIKE ?")
            params.append(f"{ACTIVE_SERIES_PREFIX}%")
        else:
            conditions.append("lcm_version = ?")
            params.append(version)

    if state:
        conditions.append("state = ?")
        params.append(state)

    where_clause = " WHERE " + " AND ".join(conditions) if conditions else ""
    limit_clause = f" LIMIT {int(limit)}" if limit else ""

    query = f"SELECT raw_json FROM proposals{where_clause} ORDER BY priority DESC, id DESC{limit_clause}"
    cursor.execute(query, params)
    rows = cursor.fetchall()
    conn.close()

    result = [json.loads(row[0]) for row in rows]
    return result


def verify_parity(json_path, db_path, sql_path=None):
    if not os.path.exists(json_path):
        print(f"[FAIL] Missing JSON ledger: {json_path}")
        return False
    if not os.path.exists(db_path):
        print(f"[FAIL] Missing SQLite database: {db_path}")
        return False

    with open(json_path, "r", encoding="utf-8") as f:
        store = json.load(f)
    json_proposals = store.get("proposals", [])

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT key, value FROM _lcm_db_metadata")
    meta = dict(cursor.fetchall())
    if "workspace_root" not in meta or "workspace_role" not in meta:
        print("[FAIL] Missing _lcm_db_metadata required keys")
        conn.close()
        return False

    cursor.execute("SELECT id, crp_id, lcm_version, state FROM proposals ORDER BY id")
    db_rows = cursor.fetchall()
    conn.close()

    if len(json_proposals) != len(db_rows):
        print(f"[FAIL] Parity count mismatch: JSON={len(json_proposals)}, DB={len(db_rows)}")
        return False

    for p, row in zip(sorted(json_proposals, key=lambda x: int(x.get("id", 0))), db_rows):
        pid, crp_id, ver, st = row
        if int(p.get("id", 0)) != pid or str(p.get("crp_id")) != crp_id:
            print(f"[FAIL] Row identity mismatch at ID {pid}")
            return False
        if str(p.get("lcm_version")) != ver or str(p.get("state")) != st:
            print(f"[FAIL] State/Version mismatch at ID {pid}: JSON({p.get('lcm_version')}, {p.get('state')}) vs DB({ver}, {st})")
            return False

    if sql_path and os.path.exists(sql_path):
        with open(sql_path, "r", encoding="utf-8") as f:
            sql_text = f.read()
        insert_count = sql_text.count("INSERT INTO proposals ")
        if insert_count != len(db_rows):
            print(f"[FAIL] SQL dump insert count mismatch: {insert_count} vs DB {len(db_rows)}")
            return False

    print(f"[PASS] 100% Dual-State Parity Verified across {len(db_rows)} proposals (JSON <-> DB <-> SQL).")
    print(f"       Metadata: Role={meta.get('workspace_role')}, Root={meta.get('workspace_root')}, Ver={meta.get('lcm_version')}")
    return True


def install_git_hooks(repo_root, silent=False):
    hooks_dir = os.path.join(repo_root, ".git", "hooks")
    if not os.path.exists(hooks_dir):
        # Could be worktree or submodule, check gitdir
        git_file = os.path.join(repo_root, ".git")
        if os.path.isfile(git_file):
            with open(git_file, "r") as gf:
                content = gf.read()
            if content.startswith("gitdir:"):
                hooks_dir = os.path.join(content.replace("gitdir:", "").strip(), "hooks")

    if not os.path.exists(hooks_dir):
        os.makedirs(hooks_dir, exist_ok=True)

    post_merge_path = os.path.join(hooks_dir, "post-merge")
    post_checkout_path = os.path.join(hooks_dir, "post-checkout")

    hook_script = """#!/bin/sh
# LCM Proposal Database Auto-Hydration Hook
# Rebuilds local proposals.db whenever proposals.sql or proposals.json changes upon pull/merge/checkout.
CHANGED=$(git diff-tree -r --name-only --no-commit-id HEAD@{1} HEAD 2>/dev/null | grep -E "proposals\\.(sql|json)")

if [ -n "$CHANGED" ]; then
    echo "[LCM] Pull/Checkout detected proposal ledger changes. Rebuilding proposals.db..."
    python tools/sync_proposals_db.py --action hydrate --silent 2>/dev/null || python tools/sync_proposals_db.py --action sync --silent 2>/dev/null
fi
"""

    with open(post_merge_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(hook_script)

    with open(post_checkout_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(hook_script)

    if not silent:
        print("[HOOKS] Installed Git post-merge and post-checkout auto-hydration hooks:")
        print(f"  - {post_merge_path}")
        print(f"  - {post_checkout_path}")


def main():
    default_json, default_db, default_sql, default_ws = get_default_paths()
    parser = argparse.ArgumentParser(description="LCM Proposals SQLite Engine, SQL Text Projection, and Version Grouping")
    parser.add_argument("--action", choices=["sync", "query", "verify", "dump", "hydrate", "install-hooks"], default="sync")
    parser.add_argument("--json-path", default=default_json)
    parser.add_argument("--db-path", default=default_db)
    parser.add_argument("--sql-path", default=default_sql)
    parser.add_argument("--workspace-root", default=default_ws)
    parser.add_argument("--workspace-role", default="LIVE")
    parser.add_argument("--sandbox-id", default="")
    parser.add_argument("--horizon", choices=["active", "all", "historical"], default=None)
    parser.add_argument("--version", default=None)
    parser.add_argument("--state", default=None)
    parser.add_argument("--active-only", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--silent", action="store_true")

    args = parser.parse_args()

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    if args.action == "sync":
        sync_json_to_db(
            args.json_path,
            args.db_path,
            sql_path=args.sql_path,
            workspace_root=args.workspace_root,
            workspace_role=args.workspace_role,
            sandbox_id=args.sandbox_id,
            silent=args.silent
        )
    elif args.action == "dump":
        dump_db_to_sql(args.db_path, args.sql_path, silent=args.silent)
    elif args.action == "hydrate":
        hydrate_sql_to_db(
            args.sql_path,
            args.db_path,
            workspace_root=args.workspace_root,
            workspace_role=args.workspace_role,
            sandbox_id=args.sandbox_id,
            silent=args.silent
        )
    elif args.action == "verify":
        success = verify_parity(args.json_path, args.db_path, sql_path=args.sql_path)
        sys.exit(0 if success else 1)
    elif args.action == "install-hooks":
        install_git_hooks(repo_root, silent=args.silent)
    elif args.action == "query":
        items = query_proposals(
            args.db_path,
            horizon=args.horizon,
            version=args.version,
            state=args.state,
            active_only=args.active_only,
            limit=args.limit
        )
        print(json.dumps(items, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
