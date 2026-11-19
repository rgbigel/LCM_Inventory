"""
Module: tools/Set-LcmWindowZone.py
Purpose: Window-placement atom (CRP-361 T6): places a visible top-level window in a named zone of its monitor's
         work area, e.g. Notepad++ beside VS Code.
Path: LCM_Inventory/tools/Set-LcmWindowZone.py
Authors: Rolf, Claude
Version: 10.7.4
Date: 2026-11-19
Rule: RULE-PY-010 (registered interpreter), CRP-361 T6
Implementation Choices (CRP-361):
  - Python with ctypes (Win32 user32 only, no packages; operator 2026-11-19: Python default for new tools).
  - Zones: left, right, top, bottom (halves of the work area), full, and beside:<title> (the space to the right of
    the reference window on its monitor; below 400 px the right half is used instead).
  - The window is found by a case-insensitive title substring (--title) and/or the process image name (--process);
    --wait-ms waits for a window that is still starting. A maximized window is restored before it is moved.
  - Non-elevated: moving windows of the same integrity level needs no rights; the DO local path runs it.
Caveats: per-monitor DPI awareness is set so the coordinates are physical pixels; windows of elevated processes
  cannot be moved from a non-elevated caller (Windows UIPI) and are reported as failed.
"""

import argparse
import ctypes
import ctypes.wintypes as wt
import os
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')

user32 = ctypes.WinDLL('user32', use_last_error=True)
kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
MIN_BESIDE_WIDTH = 400
SW_RESTORE = 9
SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010
MONITOR_DEFAULTTONEAREST = 2
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


class MONITORINFO(ctypes.Structure):
    _fields_ = [('cbSize', wt.DWORD), ('rcMonitor', wt.RECT), ('rcWork', wt.RECT), ('dwFlags', wt.DWORD)]


def set_dpi_awareness():
    try:
        user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))  # PER_MONITOR_AWARE_V2
    except (AttributeError, OSError):
        pass


def window_title(hwnd):
    length = user32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buf, length + 1)
    return buf.value


def process_image(hwnd):
    pid = wt.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
    if not handle:
        return ''
    try:
        size = wt.DWORD(1024)
        buf = ctypes.create_unicode_buffer(1024)
        if kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return os.path.basename(buf.value).lower()
        return ''
    finally:
        kernel32.CloseHandle(handle)


def find_window(title=None, process=None):
    """First visible, titled top-level window matching the title substring and/or the process image name."""
    found = []

    def callback(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        text = window_title(hwnd)
        if not text:
            return True
        if title and title.lower() not in text.lower():
            return True
        if process and process_image(hwnd) != process.lower():
            return True
        found.append(hwnd)
        return False

    user32.EnumWindows(WNDENUMPROC(callback), 0)
    return found[0] if found else None


def work_area(hwnd):
    info = MONITORINFO()
    info.cbSize = ctypes.sizeof(MONITORINFO)
    monitor = user32.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)
    if not user32.GetMonitorInfoW(monitor, ctypes.byref(info)):
        raise OSError('GetMonitorInfoW failed: ' + str(ctypes.get_last_error()))
    r = info.rcWork
    return r.left, r.top, r.right, r.bottom


def window_rect(hwnd):
    r = wt.RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(r)):
        raise OSError('GetWindowRect failed: ' + str(ctypes.get_last_error()))
    return r.left, r.top, r.right, r.bottom


def zone_rect(zone, area, reference=None):
    """Pure: target (x, y, width, height) of a zone within a work area (left, top, right, bottom)."""
    left, top, right, bottom = area
    width, height = right - left, bottom - top
    half_w, half_h = width // 2, height // 2
    if zone == 'left':
        return left, top, half_w, height
    if zone == 'right':
        return left + half_w, top, width - half_w, height
    if zone == 'top':
        return left, top, width, half_h
    if zone == 'bottom':
        return left, top + half_h, width, height - half_h
    if zone == 'full':
        return left, top, width, height
    if zone == 'beside':
        if reference is None:
            raise ValueError('zone beside needs a reference window')
        ref_right = max(left, min(reference[2], right))
        if right - ref_right < MIN_BESIDE_WIDTH:
            return left + half_w, top, width - half_w, height
        return ref_right, top, right - ref_right, height
    raise ValueError('unknown zone: ' + zone)


def main(argv=None):
    parser = argparse.ArgumentParser(prog='Set-LcmWindowZone.py',
                                     description='Place a window in a named zone (left, right, top, bottom, full, '
                                                 'beside:<title>) of its monitor work area.')
    parser.add_argument('--title', help='case-insensitive substring of the window title')
    parser.add_argument('--process', help='process image name, e.g. notepad++.exe')
    parser.add_argument('--zone', required=True, help='left | right | top | bottom | full | beside:<title>')
    parser.add_argument('--wait-ms', type=int, default=0, help='wait up to this long for the window to appear')
    args = parser.parse_args(argv)
    if not args.title and not args.process:
        parser.error('give --title and/or --process')
    set_dpi_awareness()
    deadline = time.monotonic() + max(0, args.wait_ms) / 1000.0
    hwnd = find_window(args.title, args.process)
    while hwnd is None and time.monotonic() < deadline:
        time.sleep(0.2)
        hwnd = find_window(args.title, args.process)
    if hwnd is None:
        print('window not found (title=' + str(args.title) + ', process=' + str(args.process) + ')', file=sys.stderr)
        return 2
    zone, _, ref_title = args.zone.partition(':')
    reference = None
    if zone == 'beside':
        ref = find_window(ref_title or 'Visual Studio Code')
        if ref is None:
            print('reference window not found: ' + (ref_title or 'Visual Studio Code'), file=sys.stderr)
            return 2
        reference = window_rect(ref)
    x, y, w, h = zone_rect(zone, work_area(hwnd), reference)
    if user32.IsZoomed(hwnd):
        user32.ShowWindow(hwnd, SW_RESTORE)
    if not user32.SetWindowPos(hwnd, None, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE):
        print('SetWindowPos failed (error ' + str(ctypes.get_last_error()) + '); an elevated window cannot be moved '
              'from a non-elevated caller', file=sys.stderr)
        return 1
    print('placed "' + window_title(hwnd) + '" in zone ' + args.zone + ' at ' + str((x, y, w, h)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
