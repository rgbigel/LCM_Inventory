"""
Module: tests/test_claude_eol_hook.py
Purpose: Tests of the Claude PostToolUse line-ending hook (LCM_AI/.claude/hooks/invoke_claude_eol_hook.py): it
         converts, exits 0 in every case, and logs failures instead of swallowing them (BUG-370).
Path: LCM_Inventory/tests/test_claude_eol_hook.py
Authors: Rolf, Claude
Version: 10.7.4
Date: 2026-11-19
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'LCM_AI', '.claude', 'hooks',
                    'invoke_claude_eol_hook.py')


class EolHookTests(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='lcm-eol-hook-')
        self.log = os.path.join(self.work, 'hook.log')

    def tearDown(self):
        for root, _, files in os.walk(self.work):
            for f in files:
                os.chmod(os.path.join(root, f), stat.S_IWRITE)
        shutil.rmtree(self.work, ignore_errors=True)

    def run_hook(self, payload):
        env = dict(os.environ, LCM_EOL_HOOK_LOG=self.log)
        data = payload if isinstance(payload, str) else json.dumps(payload)
        return subprocess.run([sys.executable, '-I', HOOK], input=data, capture_output=True, text=True, env=env,
                              timeout=30)

    def log_text(self):
        return open(self.log, encoding='utf-8').read() if os.path.exists(self.log) else ''

    def test_converts_and_logs_nothing(self):
        path = os.path.join(self.work, 'a.md')
        with open(path, 'wb') as h:
            h.write(b'x\r\ny\r\n')
        r = self.run_hook({'tool_input': {'file_path': path}})
        self.assertEqual(r.returncode, 0)
        self.assertEqual(open(path, 'rb').read(), b'x\ny\n')
        self.assertEqual(self.log_text(), '')

    def test_failed_repair_is_logged_and_exit_0(self):
        path = os.path.join(self.work, 'ro.md')
        with open(path, 'wb') as h:
            h.write(b'x\r\n')
        os.chmod(path, stat.S_IREAD)
        r = self.run_hook({'tool_input': {'file_path': path}})
        self.assertEqual(r.returncode, 0)
        self.assertIn('[ERROR] ' + path + ' | repair failed', self.log_text())

    def test_invalid_payload_is_logged_and_exit_0(self):
        r = self.run_hook('{not json')
        self.assertEqual(r.returncode, 0)
        self.assertIn('[ERROR] None |', self.log_text())
        self.assertIn('JSONDecodeError', self.log_text())

    def test_no_path_is_silent(self):
        r = self.run_hook({'tool_input': {}})
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.log_text(), '')


if __name__ == '__main__':
    unittest.main()
