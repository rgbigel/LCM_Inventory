"""
Module: tools/Export-LcmElevationPolicy.py
Purpose: Reads LCM_Inventory/data/tools/tools.db read-only and (1) exports the atom-level
         elevation policy the DO daemon enforces (data/tools/elevation_policy.json),
         (2) checks the CRP-343 consistency invariant and reports violations.
Path: LCM_Inventory/tools/Export-LcmElevationPolicy.py
Authors: Rolf, Claude
Version: 10.7.5
Date: 2026-11-19
Rule: RULE-ELEV-001, RULE-ELEV-003, RULE-ELEV-006 (CRP-343)
Implementation Choices (CRP-343):
  - tool_intents.elevated is the atom-level authority (runs elevated); tools.admin is the
    tool-level access restriction (admin users only). An intent is joined to its owning tool
    by script path (tool_intents.script == tools.relative_path, separators normalized).
  - The daemon has no SQLite driver (Go, no dependencies), so it reads this generated JSON;
    the JSON is a mechanical artifact (RULE-EFF-001 class) regenerated from tools.db.
  - Direct-caller check (operator 2026-11-17, option A): an elevated atom may be invoked
    directly only by admin tools; a non-admin tool may call admin tools. Only real invocation
    lines count (&, -File, do.exe/do.cmd, Start-Process, Join-Path building the path);
    comment lines and mere mentions (e.g. catalog data) are ignored.
Implementation Choices (CRP-343 segment 2): tools.admin is a level 0 = TBD, 1 = granted, 2 = controlled, 3 = admin.
  An elevated atom is legal only when its owning tool has level 3; a controlled tool may call the elevated atoms of
  its list (table tool_atom_permissions) through the DO; levels 0 and 1 call no elevated atom. The policy carries the
  levels and the lists for the daemon's caller check.
Implementation Choices (CRP-343, 2026-11-19, operator option C): property assignments of a string literal
  (catalog seed data such as Example = 'pwsh -File ...') are mentions, not calls (DATA_LITERAL); so are HTML markup
  lines such as a button's onclick command string (MARKUP_LINE; operator case 18, 2026-11-19).
Caveats: the database is opened with mode=ro; this tool never writes tools.db.
"""

import argparse
import datetime
import json
import os
import re
import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

GIT_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
CALL_MARKERS = re.compile(r'(^|\s)&\s|-file\s|\bdo(\.exe|\.cmd)?\s|start-process|join-path', re.IGNORECASE)
DATA_LITERAL = re.compile(r'^[a-z_][a-z0-9_]*\s*=\s*[\x27"]')  # Name = '...': catalog data, not a call
MARKUP_LINE = re.compile(r'^<[a-z!/]')  # <button onclick=...>: HTML markup, not a call
SOURCE_EXT = ('.ps1', '.psm1', '.cmd', '.bat', '.py')
DB_PATH = os.path.join(GIT_ROOT, 'LCM_Inventory', 'data', 'tools', 'tools.db')
OUT_PATH = os.path.join(GIT_ROOT, 'LCM_Inventory', 'data', 'tools', 'elevation_policy.json')
SOURCE_EXT = ('.ps1', '.psm1', '.cmd', '.bat', '.py')


def norm(path):
    """Normalize a repository-relative path for comparison."""
    if not path:
        return ''
    return path.replace('\\', '/').strip().lstrip('./').lower()


def load(db_path):
    """Return (elevated intents grouped by script, tools by path)."""
    con = sqlite3.connect('file:' + db_path.replace('\\', '/') + '?mode=ro', uri=True)
    try:
        tools = {}
        for rel, admin, name in con.execute('SELECT relative_path, admin, name FROM tools'):
            tools[norm(rel)] = {'relative_path': rel, 'admin': int(admin), 'name': name, 'allowed_atoms': []}
        has_permissions = con.execute(
            "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'tool_atom_permissions'").fetchone()[0]
        if has_permissions:
            for rel, intent_key in con.execute('SELECT tool_relative_path, intent_key FROM tool_atom_permissions'):
                tool = tools.get(norm(rel))
                if tool is not None:
                    tool['allowed_atoms'].append(str(intent_key).lower())
        atoms = {}
        for key, exe, script, params in con.execute(
                'SELECT intent_key, executable, script, parameters FROM tool_intents WHERE elevated = 1 ORDER BY intent_key'):
            k = norm(script) or norm(exe)
            entry = atoms.setdefault(k, {'script': script or '', 'executable': exe or '', 'intent_keys': [], 'parameters': ''})
            entry['intent_keys'].append(key)
            p = (params or '').strip()
            if p.startswith('-') and not entry['parameters']:
                entry['parameters'] = p
    finally:
        con.close()
    return atoms, tools


def check(atoms, tools):
    """Return the list of consistency violations."""
    violations = []
    for k, atom in sorted(atoms.items()):
        owner = tools.get(k)
        if owner is None:
            violations.append({'kind': 'elevated-atom-without-tool', 'atom': atom['script'] or atom['executable'],
                               'detail': 'no tools row for the elevated atom'})
        elif owner['admin'] != 3:
            violations.append({'kind': 'elevated-atom-in-non-admin-tool', 'atom': atom['script'],
                               'detail': 'owning tool has admin level {0} (3 required)'.format(owner['admin'])})
    leaves = {os.path.basename(k): atom['script'] for k, atom in atoms.items() if k}
    keys_by_leaf = {os.path.basename(k): set(a['intent_keys']) for k, a in atoms.items() if k}
    for k, tool in sorted(tools.items()):
        if tool['admin'] == 3 or not k.endswith(SOURCE_EXT):
            continue
        path = os.path.join(GIT_ROOT, tool['relative_path'].replace('\\', os.sep))
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                lines = fh.read().lower().splitlines()
        except OSError:
            continue
        own = os.path.basename(k)
        for leaf, script in sorted(leaves.items()):
            if leaf == own:
                continue
            for no, line in enumerate(lines, 1):
                s = line.strip()
                if (leaf in s and not s.startswith(('#', 'rem ', '::', '//')) and not DATA_LITERAL.match(s) and not MARKUP_LINE.match(s)
                        and CALL_MARKERS.search(s)):
                    if tool['admin'] == 2 and keys_by_leaf.get(leaf, set()) & set(tool['allowed_atoms']):
                        break  # controlled tool, atom in its list (CRP-343): allowed through the DO
                    kind = 'controlled-tool-invokes-unlisted-atom' if tool['admin'] == 2 else 'non-admin-tool-invokes-elevated-atom'
                    violations.append({'kind': kind, 'tool': tool['relative_path'], 'atom': script,
                                       'detail': 'admin level {0}; line {1}: {2}'.format(tool['admin'], no, s[:160])})
                    break
    return violations


def main(argv):
    parser = argparse.ArgumentParser(description='Export the DO elevation policy from tools.db and check consistency (CRP-343).')
    parser.add_argument('--check', action='store_true', help='report only; exit 3 when violations exist; write nothing')
    parser.add_argument('--db', default=DB_PATH, help='tools.db path (read-only)')
    parser.add_argument('--out', default=OUT_PATH, help='policy JSON output path')
    args = parser.parse_args(argv)

    atoms, tools = load(args.db)
    violations = check(atoms, tools)
    print('Elevated atoms: {0}; tools: {1}; consistency violations: {2}'.format(len(atoms), len(tools), len(violations)))
    for v in violations:
        print('  [{0}] {1} -> {2}'.format(v['kind'], v.get('tool', '-'), v['atom']))
    if args.check:
        return 3 if violations else 0

    policy = {
        'generated_at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'generator': 'LCM_Inventory/tools/Export-LcmElevationPolicy.py',
        'source': 'LCM_Inventory/data/tools/tools.db',
        'rule': 'CRP-343: elevated only for atoms with tool_intents.elevated = 1 whose owning tool has admin level 3; callers: level 3, or level 2 with the atom in its list',
        'levels': {'0': 'TBD', '1': 'granted', '2': 'controlled', '3': 'admin'},
        'elevated_atoms': [
            {'script': a['script'], 'executable': a['executable'], 'intent_keys': a['intent_keys'],
             'parameters': a['parameters'], 'tool_admin': (tools.get(k) or {}).get('admin', 0)}
            for k, a in sorted(atoms.items())
        ],
        'tools': {t['relative_path']: t['admin'] for t in sorted(tools.values(), key=lambda v: v['relative_path'])},
        'allowed_atoms': {t['relative_path']: sorted(t['allowed_atoms']) for t in sorted(tools.values(), key=lambda v: v['relative_path']) if t['allowed_atoms']},
        'violations': violations,
    }
    tmp = args.out + '.tmp'
    with open(tmp, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(policy, fh, indent=2)
        fh.write('\n')
    os.replace(tmp, args.out)
    print('Wrote ' + args.out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
