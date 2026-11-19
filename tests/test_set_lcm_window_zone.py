"""
Module: tests/test_set_lcm_window_zone.py
Purpose: Unit tests of the zone geometry of tools/Set-LcmWindowZone.py (CRP-361 T6), plus one live placement of a
         Notepad window started by the test itself (skipped when no desktop is available).
Path: LCM_Inventory/tests/test_set_lcm_window_zone.py
Authors: Rolf, Claude
Version: 10.7.4
Date: 2026-11-19
"""

import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import unittest

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools', 'Set-LcmWindowZone.py')
_spec = importlib.util.spec_from_file_location('set_lcm_window_zone', TOOL)
wz = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wz)
AREA = (0, 0, 2000, 1000)


class ZoneGeometryTests(unittest.TestCase):

    def test_halves(self):
        self.assertEqual(wz.zone_rect('left', AREA), (0, 0, 1000, 1000))
        self.assertEqual(wz.zone_rect('right', AREA), (1000, 0, 1000, 1000))
        self.assertEqual(wz.zone_rect('top', AREA), (0, 0, 2000, 500))
        self.assertEqual(wz.zone_rect('bottom', AREA), (0, 500, 2000, 500))
        self.assertEqual(wz.zone_rect('full', AREA), (0, 0, 2000, 1000))

    def test_beside_uses_space_right_of_reference(self):
        self.assertEqual(wz.zone_rect('beside', AREA, reference=(0, 0, 1200, 1000)), (1200, 0, 800, 1000))

    def test_beside_falls_back_to_right_half_when_too_narrow(self):
        self.assertEqual(wz.zone_rect('beside', AREA, reference=(0, 0, 1800, 1000)), (1000, 0, 1000, 1000))

    def test_unknown_zone(self):
        with self.assertRaises(ValueError):
            wz.zone_rect('middle', AREA)


@unittest.skipUnless(os.environ.get('LCM_LIVE_WINDOW_TEST') == '1', 'set LCM_LIVE_WINDOW_TEST=1 for the live test')
class LivePlacementTest(unittest.TestCase):

    def test_places_own_notepad_window(self):
        marker = 'lcm-zone-test-' + str(os.getpid())
        path = os.path.join(tempfile.gettempdir(), marker + '.txt')
        with open(path, 'w', encoding='utf-8') as h:
            h.write('CRP-361 T6 live test\n')
        proc = subprocess.Popen(['notepad.exe', path])
        try:
            run = subprocess.run([sys.executable, '-I', TOOL, '--title', marker, '--zone', 'left', '--wait-ms', '8000'],
                                 capture_output=True, text=True, timeout=30)
            self.assertEqual(run.returncode, 0, run.stderr)
            wz.set_dpi_awareness()
            hwnd = wz.find_window(marker)
            x, y, r, b = wz.window_rect(hwnd)
            left, top, right, bottom = wz.work_area(hwnd)
            self.assertLessEqual(abs((r - x) - (right - left) // 2), 20)
        finally:
            hwnd = wz.find_window(marker)
            if hwnd:
                wz.user32.PostMessageW(hwnd, 0x0010, 0, 0)  # WM_CLOSE
            time.sleep(0.5)
            proc.kill() if proc.poll() is None else None
            os.unlink(path)


if __name__ == '__main__':
    unittest.main()
