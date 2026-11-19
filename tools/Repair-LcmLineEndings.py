"""
Module: tools/Repair-LcmLineEndings.py
Purpose: Single source of the LCM line-ending policy: reports or converts text files to their target line ending
         (CRLF for Windows-native consumers that mis-parse LF, LF for every other text file).
Path: LCM_Inventory/tools/Repair-LcmLineEndings.py
Authors: Rolf, Claude
Version: 10.7.5
Date: 2026-11-19
Rule: InvariantRules newline-lf (BUG-365; operator Option B 2026-11-16, CRP-332 section 0a)
Implementation Choices (BUG-365):
  - Python rewrite of LcmLineEndingAtoms.psm1 / Repair-LcmLineEndings.ps1 (operator 2026-11-19: Python default,
    rewrite instead of adjust). Used by the Claude hook, Submit-ReviewResult.ps1 and one-time conversions.
  - Target by extension: CRLF_EXTENSIONS get CRLF, every other text file LF. Byte level: only line breaks change;
    BOM, encoding and all other bytes stay as they are.
  - Binary detection: NUL byte in the first 8 KiB or a UTF-16/32 BOM -> skipped (covers UTF-16 *.reg files).
  - Live append targets (*.log, *.jsonl) are never rewritten in place: a running writer could leave NUL gaps.
  - Vendor-signed venv scripts (Activate.ps1) are left unchanged; there is no signing certificate to re-sign them.
  - Files are rewritten in place (r+b, truncate) so hard links stay intact.
  - A run of CRs before an LF (\r\r\n, trace of an earlier double conversion) is one line break; a lone CR is kept.
  - Directory walks never follow junctions or symbolic links.
Caveats: a file locked by another process is reported as failed, not retried.
"""

import argparse
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

CRLF_EXTENSIONS = frozenset({'.cmd', '.bat', '.reg', '.bas', '.cls', '.frm'})
SKIP_EXTENSIONS = frozenset({'.log', '.jsonl'})
SKIP_NAMES = frozenset({'activate.ps1', 'activate_py.ps1'})
EXCLUDED_DIRS = frozenset({'.git', 'node_modules', '.venv', 'venv', '__pycache__'})
BINARY_EXTENSIONS = frozenset({
    '.exe', '.dll', '.db', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.zip', '.7z', '.pdf', '.mrimgx', '.msg',
    '.pyc', '.woff', '.woff2', '.ttf', '.otf', '.docx', '.xlsx', '.pptx', '.sqlite', '.bin', '.iso', '.cab',
    '.msi', '.lnk', '.dat', '.pdb', '.obj', '.lib', '.so', '.frx'})


def target_ending(path):
    """Returns b'\\r\\n' or b'\\n' for a governed path, or None when the path is not governed."""
    name = os.path.basename(path).lower()
    ext = os.path.splitext(name)[1]
    if ext in SKIP_EXTENSIONS or ext in BINARY_EXTENSIONS or name in SKIP_NAMES:
        return None
    parts = {p.lower() for p in os.path.normpath(path).split(os.sep)}
    if parts & EXCLUDED_DIRS:
        return None
    return b'\r\n' if ext in CRLF_EXTENSIONS else b'\n'


def is_binary(data):
    """True for content that must not be touched: NUL byte in the first 8 KiB or a UTF-16/32 BOM."""
    return data[:2] in (b'\xff\xfe', b'\xfe\xff') or b'\x00' in data[:8192]


LINE_BREAK = re.compile(b'\r*\n')


def convert(data, ending):
    """Pure function: every line break (LF preceded by any number of CRs) becomes `ending`; a lone CR is kept."""
    normalized = LINE_BREAK.sub(b'\n', data)
    return normalized if ending == b'\n' else normalized.replace(b'\n', b'\r\n')


def repair_file(path, apply=False):
    """Checks one file; with apply=True converts it in place. Returns a result dict."""
    result = {'path': path, 'status': 'clean', 'target': '', 'reason': ''}
    if not os.path.isfile(path):
        result.update(status='skipped', reason='not a file')
        return result
    ending = target_ending(path)
    if ending is None:
        result.update(status='skipped', reason='not a governed type')
        return result
    result['target'] = 'CRLF' if ending == b'\r\n' else 'LF'
    try:
        with open(path, 'rb') as handle:
            data = handle.read()
        if is_binary(data):
            result.update(status='skipped', reason='binary or UTF-16/32')
            return result
        converted = convert(data, ending)
        if converted == data:
            return result
        if not apply:
            result['status'] = 'would_convert'
            return result
        with open(path, 'r+b') as handle:
            handle.seek(0)
            handle.write(converted)
            handle.truncate()
        result['status'] = 'converted'
    except OSError as error:
        result.update(status='failed', reason=str(error))
    return result


def iter_files(root, recurse=True):
    """Yields the files below root without following junctions, symbolic links or excluded directories."""
    if os.path.isfile(root):
        yield root
        return
    pending = [root]
    while pending:
        current = pending.pop()
        try:
            entries = list(os.scandir(current))
        except OSError:
            continue
        for entry in entries:
            if entry.is_symlink() or os.path.isjunction(entry.path):
                continue
            if entry.is_dir(follow_symlinks=False):
                if recurse and entry.name.lower() not in EXCLUDED_DIRS:
                    pending.append(entry.path)
            elif entry.is_file(follow_symlinks=False):
                yield entry.path


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog='Repair-LcmLineEndings.py',
        description='Report (default) or convert (--apply) line endings to the LCM policy: CRLF for '
                    + ', '.join(sorted(CRLF_EXTENSIONS)) + '; LF for every other text file.')
    parser.add_argument('paths', nargs='*', help='files or directories')
    parser.add_argument('--stdin', action='store_true', help='also read paths from stdin, one per line')
    parser.add_argument('--apply', action='store_true', help='convert in place (default: dry run)')
    parser.add_argument('--no-recurse', action='store_true', help='do not descend into subdirectories')
    parser.add_argument('--json', action='store_true', help='print one JSON object per non-clean file')
    parser.add_argument('--quiet', action='store_true', help='print the summary line only')
    args = parser.parse_args(argv)
    paths = list(args.paths)
    if args.stdin:
        paths.extend(line.strip() for line in sys.stdin if line.strip())
    if not paths:
        parser.error('no paths given')
    counts = {'clean': 0, 'would_convert': 0, 'converted': 0, 'skipped': 0, 'failed': 0}
    for root in paths:
        for path in iter_files(root, recurse=not args.no_recurse):
            result = repair_file(path, apply=args.apply)
            counts[result['status']] += 1
            if result['status'] in ('would_convert', 'converted', 'failed') and not args.quiet:
                if args.json:
                    print(json.dumps(result, ensure_ascii=False))
                else:
                    print('{0:<13} {1:<4} {2} {3}'.format(result['status'], result['target'], path,
                                                         result['reason']).rstrip())
    mode = 'apply' if args.apply else 'dry-run'
    print('Repair-LcmLineEndings ' + mode + ': ' + ', '.join(k + '=' + str(v) for k, v in counts.items()))
    return 1 if counts['failed'] else 0


if __name__ == '__main__':
    sys.exit(main())
