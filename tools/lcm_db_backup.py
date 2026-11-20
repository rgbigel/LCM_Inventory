#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module: tools/lcm_db_backup.py
Purpose: Restructuring backups of the LCM SQLite stores: a full SQL backup is written before any schema change
         (detected by a dry run of the schema setup on an in-memory copy of the schema) and before a rebuild at pull;
         the item's completion deletes the backups once its checks passed.
Path: LCM_Inventory/tools/lcm_db_backup.py
Authors: Rolf, Claude
Version: 10.8.4
Status: Production Engine
Date: 2026-11-20 22:20:00
Implementation Choices (CRP-358): restructuring backups are not publish projections: they live in the git-ignored
scratch/db-backups/ (never committed), are written only when the schema would change (or before a rebuild), and are
deleted by Complete-Review.ps1 after a successful completion (learned advice 2026-11-18: dump before restructuring,
delete after the completion checks). A failed backup stops the schema change.
Caveats: the dry run copies the schema only (no rows); a setup step whose schema effect depends on row content would
not be detected (none exists today).
"""

import argparse
import glob
import os
import sqlite3
import sys
from datetime import datetime

sys.stdout.reconfigure(encoding="utf-8")

BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scratch", "db-backups")


def schema_text(conn):
    """Normalized schema of a database (every object's SQL, ordered)."""
    rows = conn.execute(
        "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type, name"
    ).fetchall()
    return "\n".join(f"{t}|{n}|{' '.join(s.split())}" for t, n, s in rows)


def schema_only_copy(conn):
    """In-memory database holding the same tables, indexes and views (no rows)."""
    mem = sqlite3.connect(":memory:")
    objects = conn.execute(
        "SELECT type, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
        "ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 WHEN 'view' THEN 2 ELSE 3 END"
    ).fetchall()
    for _, sql in objects:
        mem.execute(sql)
    mem.commit()
    return mem


def write_backup(db_path, label):
    """Writes a full SQL backup of db_path to scratch/db-backups/; raises on any failure (callers stop then)."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    target = os.path.join(BACKUP_DIR, f"{label}-{stamp}.sql")
    temp = target + ".tmp"
    conn = sqlite3.connect(db_path)
    try:
        with open(temp, "w", encoding="utf-8", newline="\n") as f:
            for line in conn.iterdump():
                f.write(line + "\n")
    finally:
        conn.close()
    os.replace(temp, target)
    return target


def guarded_schema_setup(db_path, setup_fn, label):
    """Runs setup_fn(conn) on db_path; when it would change the schema, writes a backup first.
    Returns the backup path or None."""
    backup = None
    if os.path.exists(db_path) and os.path.getsize(db_path) > 0:
        real = sqlite3.connect(db_path)
        try:
            before = schema_text(real)
            mem = schema_only_copy(real)
        finally:
            real.close()
        try:
            setup_fn(mem)
            mem.commit()
            after = schema_text(mem)
        finally:
            mem.close()
        if after != before:
            backup = write_backup(db_path, label)
            print(f"[BACKUP] schema change ahead: {backup}", file=sys.stderr)
    conn = sqlite3.connect(db_path)
    try:
        setup_fn(conn)
        conn.commit()
    finally:
        conn.close()
    return backup


def purge_backups():
    """Deletes every restructuring backup (called after a successful completion)."""
    files = glob.glob(os.path.join(BACKUP_DIR, "*.sql"))
    for f in files:
        os.remove(f)
    return len(files)


def main():
    parser = argparse.ArgumentParser(description="LCM restructuring backups (CRP-358)")
    parser.add_argument("--backup", metavar="DB", help="write a backup of this database now")
    parser.add_argument("--label", default="manual")
    parser.add_argument("--purge", action="store_true", help="delete all restructuring backups")
    parser.add_argument("--list", action="store_true", help="list the restructuring backups")
    args = parser.parse_args()
    if args.backup:
        print(write_backup(args.backup, args.label))
    if args.list:
        for f in sorted(glob.glob(os.path.join(BACKUP_DIR, "*.sql"))):
            print(f)
    if args.purge:
        print(f"[PURGE] {purge_backups()} restructuring backup(s) deleted from {BACKUP_DIR}")


if __name__ == "__main__":
    main()
