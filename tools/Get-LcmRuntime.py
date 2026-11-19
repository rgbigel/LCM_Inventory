"""
Module: tools/Get-LcmRuntime.py
Purpose: Reads (and on operator instruction sets) the interpreter registry, table runtimes in
         LCM_Inventory/data/tools/tools.db: the one place that names which executable runs LCM code.
Path: LCM_Inventory/tools/Get-LcmRuntime.py
Authors: Rolf, Claude
Version: 10.7.5
Date: 2026-11-19
Rule: RULE-PY-010 (CRP-366)
Implementation Choices (CRP-366):
  - Schema and seed rows are owned by sync_tool_catalog_db.py (ensure_runtimes), loaded here by file path so the
    tool also works under python -I.
  - Any interpreter may run this reader (bootstrap): the answer comes from the table, so it is the same whichever
    Python reads it.
  - Entries inside the git root are stored relative to it and resolved here (operator 2026-11-19, CRP-253).
  - 'get' fails (exit 2) when the key is unknown or the registered executable does not exist; callers never fall
    back silently to a PATH lookup.
Caveats: 'set' writes tools.db; the committed projection tools.sql is refreshed by the next catalog dump.
"""

import argparse
import importlib.util
import os
import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(TOOLS_DIR, '..', 'data', 'tools', 'tools.db')
GIT_ROOT = os.path.abspath(os.path.join(TOOLS_DIR, '..', '..'))


def load_sync_module():
    spec = importlib.util.spec_from_file_location('sync_tool_catalog_db',
                                                  os.path.join(TOOLS_DIR, 'sync_tool_catalog_db.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def connect(db_path):
    conn = sqlite3.connect(db_path)
    load_sync_module().ensure_runtimes(conn)
    return conn


def resolve(path):
    """A relative registry entry lies inside the git root (operator 2026-11-19); absolute entries are machine tools."""
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(GIT_ROOT, path))


def get_runtime(key, db_path=DB_PATH):
    """Returns the registered executable path for key (resolved), or None."""
    conn = connect(db_path)
    try:
        row = conn.execute('SELECT executable_path FROM runtimes WHERE runtime_key = ?', (key,)).fetchone()
    finally:
        conn.close()
    return resolve(row[0]) if row else None


def main(argv=None):
    parser = argparse.ArgumentParser(prog='Get-LcmRuntime.py',
                                     description='Interpreter registry (tools.db table runtimes).')
    sub = parser.add_subparsers(dest='action', required=True)
    get = sub.add_parser('get', help='print the executable path of a runtime key')
    get.add_argument('key')
    sub.add_parser('list', help='list all runtimes')
    put = sub.add_parser('set', help='register or change a runtime (operator instruction only)')
    put.add_argument('key')
    put.add_argument('path')
    put.add_argument('--purpose', required=True)
    parser.add_argument('--db', default=DB_PATH, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.action == 'get':
        path = get_runtime(args.key, args.db)
        if not path:
            print('runtime not registered: ' + args.key, file=sys.stderr)
            return 2
        if not os.path.isfile(path):
            print('registered executable missing: ' + path, file=sys.stderr)
            return 2
        print(path)
        return 0
    conn = connect(args.db)
    try:
        if args.action == 'set':
            conn.execute('INSERT INTO runtimes (runtime_key, executable_path, purpose, updated_at) '
                         "VALUES (?, ?, ?, datetime('now', 'localtime')) ON CONFLICT(runtime_key) DO UPDATE SET "
                         'executable_path = excluded.executable_path, purpose = excluded.purpose, '
                         'updated_at = excluded.updated_at', (args.key, args.path, args.purpose))
            conn.commit()
        for key, path, purpose, updated in conn.execute(
                'SELECT runtime_key, executable_path, purpose, updated_at FROM runtimes ORDER BY runtime_key'):
            exists = 'ok' if os.path.isfile(resolve(path)) else 'MISSING'
            print(key + ' | ' + path + ' | ' + exists + ' | ' + purpose + ' | ' + updated)
    finally:
        conn.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
