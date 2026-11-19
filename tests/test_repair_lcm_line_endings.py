"""
Module: tests/test_repair_lcm_line_endings.py
Purpose: Unit tests for tools/Repair-LcmLineEndings.py (line-ending policy, byte-level conversion, skip rules).
Path: LCM_Inventory/tests/test_repair_lcm_line_endings.py
Authors: Rolf, Claude
Version: 10.7.5
Date: 2026-11-19
Implementation Choices (BUG-365): replaces tests/LcmLineEndingAtoms.Tests.ps1; stdlib unittest (no pytest on the
  base interpreter). Run: python -I -m unittest discover -s LCM_Inventory/tests -p "test_*.py"
"""

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools', 'Repair-LcmLineEndings.py')
_spec = importlib.util.spec_from_file_location('repair_lcm_line_endings', TOOL)
eol = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(eol)


class LineEndingPolicyTests(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='lcm-eol-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def write(self, name, data):
        path = os.path.join(self.work, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as handle:
            handle.write(data)
        return path

    def read(self, path):
        with open(path, 'rb') as handle:
            return handle.read()

    def test_convert_to_lf_and_crlf(self):
        self.assertEqual(eol.convert(b'a\r\nb\nc\r\n', b'\n'), b'a\nb\nc\n')
        self.assertEqual(eol.convert(b'a\r\nb\nc', b'\r\n'), b'a\r\nb\r\nc')

    def test_collapses_doubled_cr(self):
        self.assertEqual(eol.convert(b'a\r\r\nb\r\r\r\n', b'\n'), b'a\nb\n')
        once = eol.convert(b'a\r\r\nb', b'\r\n')
        self.assertEqual(once, b'a\r\nb')
        self.assertEqual(eol.convert(once, b'\r\n'), once)

    def test_convert_is_idempotent_and_keeps_lone_cr(self):
        once = eol.convert(b'a\nb\rc', b'\r\n')
        self.assertEqual(eol.convert(once, b'\r\n'), once)
        self.assertIn(b'b\rc', once)

    def test_target_by_extension(self):
        self.assertEqual(eol.target_ending('D:\\x\\a.ps1'), b'\n')
        self.assertEqual(eol.target_ending('D:\\x\\a.md'), b'\n')
        self.assertEqual(eol.target_ending('D:\\x\\.gitattributes'), b'\n')
        for name in ('a.cmd', 'a.BAT', 'a.reg', 'm.bas', 'c.cls', 'f.frm'):
            self.assertEqual(eol.target_ending('D:\\x\\' + name), b'\r\n', name)

    def test_not_governed(self):
        for path in ('D:\\x\\a.log', 'D:\\x\\a.jsonl', 'D:\\x\\a.png', 'D:\\x\\Activate.ps1',
                     'D:\\x\\.git\\config', 'D:\\x\\node_modules\\a.js'):
            self.assertIsNone(eol.target_ending(path), path)

    def test_apply_converts_in_place_and_keeps_bom(self):
        path = self.write('bom.md', b'\xef\xbb\xbfa\r\nb')
        self.assertEqual(eol.repair_file(path, apply=True)['status'], 'converted')
        self.assertEqual(self.read(path), b'\xef\xbb\xbfa\nb')
        self.assertEqual(eol.repair_file(path, apply=True)['status'], 'clean')

    def test_dry_run_does_not_write(self):
        path = self.write('run.cmd', b'@echo off\necho x\n')
        self.assertEqual(eol.repair_file(path)['status'], 'would_convert')
        self.assertEqual(self.read(path), b'@echo off\necho x\n')

    def test_skips_binary_and_utf16(self):
        wide = self.write('wide.reg', b'\xff\xfeW\x00\r\x00\n\x00')
        self.assertEqual(eol.repair_file(wide, apply=True)['status'], 'skipped')
        nul = self.write('nul.txt', b'a\x00\r\n')
        self.assertEqual(eol.repair_file(nul, apply=True)['status'], 'skipped')

    def test_hard_link_survives(self):
        path = self.write('a.py', b'x = 1\r\n')
        link = os.path.join(self.work, 'b.py')
        os.link(path, link)
        eol.repair_file(path, apply=True)
        self.assertEqual(self.read(link), b'x = 1\n')

    def test_walk_does_not_follow_junctions(self):
        self.write('sub\\x.ps1', b'a')
        link = os.path.join(self.work, 'link')
        subprocess.run(['cmd', '/c', 'mklink', '/J', link, os.path.join(self.work, 'sub')],
                       check=True, capture_output=True)
        found = [p for p in eol.iter_files(self.work) if p.endswith('x.ps1')]
        self.assertEqual(len(found), 1)
        os.rmdir(link)

    def test_cli_stdin_apply(self):
        path = self.write('s.json', b'{\r\n}\r\n')
        run = subprocess.run([sys.executable, '-I', TOOL, '--apply', '--json', '--stdin'], input=path + '\n',
                             capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn('"converted"', run.stdout)
        self.assertEqual(self.read(path), b'{\n}\n')


if __name__ == '__main__':
    unittest.main()
