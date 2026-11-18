/*
================================================================================
FILE NAME      : winutil.go
PACKAGE        : main
DESCRIPTION    : Windows platform utilities, process attributes, and Win32 interop.
AUTHOR         : Rolf
DATE CREATED   : 2026-11-11
LAST MODIFIED  : 2026-11-18
VERSION        : 10.2.5
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-11 - 10.0.0: Initial implementation.
2026-11-18 - 10.2.5: CRP-354 BringWindowToForeground passes the foreground lock (AttachThreadInput to the
                     foreground thread, BringWindowToTop, SetForegroundWindow, verified); WaitForWindowForeground.
================================================================================
*/

package main

import (
	"fmt"
	"os"
	"os/user"
	"runtime"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

var (
	modkernel32              = syscall.NewLazyDLL("kernel32.dll")
	moduser32                = syscall.NewLazyDLL("user32.dll")
	procProcessIdToSessionId = modkernel32.NewProc("ProcessIdToSessionId")
	procGetConsoleWindow     = modkernel32.NewProc("GetConsoleWindow")
	procSetForegroundWindow  = moduser32.NewProc("SetForegroundWindow")
	procShowWindow           = moduser32.NewProc("ShowWindow")
	procEnumWindows          = moduser32.NewProc("EnumWindows")
	procGetWindowTextW       = moduser32.NewProc("GetWindowTextW")
	procIsWindowVisible      = moduser32.NewProc("IsWindowVisible")
	procGetForegroundWindow  = moduser32.NewProc("GetForegroundWindow")
	procAttachThreadInput    = moduser32.NewProc("AttachThreadInput")
	procBringWindowToTop     = moduser32.NewProc("BringWindowToTop")
	procIsIconic             = moduser32.NewProc("IsIconic")
	procGetCurrentThreadId   = modkernel32.NewProc("GetCurrentThreadId")
)

const (
	swRestore        = 9
	swShow           = 5
	createNoWindow   = 0x08000000
	createNewConsole = 0x00000010
	detachedProcess  = 0x00000008
)

// GetCurrentSessionID returns the Windows Terminal Services session ID for the current process.
func GetCurrentSessionID() int {
	pid := uint32(os.Getpid())
	var sessionID uint32
	r1, _, _ := procProcessIdToSessionId.Call(uintptr(pid), uintptr(unsafe.Pointer(&sessionID)))
	if r1 == 0 {
		return 1 // Default fallback for Windows desktop session
	}
	return int(sessionID)
}

// GetCurrentUsername returns the DOMAIN\username or username for the current process.
func GetCurrentUsername() string {
	u, err := user.Current()
	if err != nil {
		uName := os.Getenv("USERNAME")
		if uName != "" {
			return uName
		}
		return "unknown"
	}
	return u.Username
}

// BringWindowToForeground attempts to find a visible top-level window matching titleSubstring and bring it to front.
func BringWindowToForeground(titleSubstring string) bool {
	if strings.TrimSpace(titleSubstring) == "" {
		return false
	}
	lowerTarget := strings.ToLower(titleSubstring)
	var foundHwnd uintptr

	cb := syscall.NewCallback(func(hwnd uintptr, lParam uintptr) uintptr {
		vis, _, _ := procIsWindowVisible.Call(hwnd)
		if vis == 0 {
			return 1 // Continue enumeration
		}
		buf := make([]uint16, 512)
		length, _, _ := procGetWindowTextW.Call(hwnd, uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
		if length > 0 {
			title := syscall.UTF16ToString(buf[:length])
			if strings.Contains(strings.ToLower(title), lowerTarget) {
				foundHwnd = hwnd
				return 0 // Stop enumeration
			}
		}
		return 1 // Continue enumeration
	})

	_, _, _ = procEnumWindows.Call(cb, 0)
	if foundHwnd != 0 {
		activateWindow(foundHwnd)
		return true
	}
	return false
}

// activateWindow brings hwnd to the foreground. A background process (the daemon) is refused by the Windows
// foreground lock with a plain SetForegroundWindow; attaching this thread's input to the thread that owns the
// current foreground window lifts that restriction for the call (CRP-354). Returns whether hwnd is in front.
func activateWindow(hwnd uintptr) bool {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if iconic, _, _ := procIsIconic.Call(hwnd); iconic != 0 {
		procShowWindow.Call(hwnd, uintptr(swRestore))
	} else {
		procShowWindow.Call(hwnd, uintptr(swShow))
	}
	for attempt := 0; attempt < 3; attempt++ {
		fg, _, _ := procGetForegroundWindow.Call()
		if fg == hwnd {
			return true
		}
		self, _, _ := procGetCurrentThreadId.Call()
		var fgThread uintptr
		if fg != 0 {
			fgThread, _, _ = procGetWndThrPid.Call(fg, 0)
		}
		attached := false
		if fgThread != 0 && fgThread != self {
			r, _, _ := procAttachThreadInput.Call(self, fgThread, 1)
			attached = r != 0
		}
		procBringWindowToTop.Call(hwnd)
		procSetForegroundWindow.Call(hwnd)
		if attached {
			procAttachThreadInput.Call(self, fgThread, 0)
		}
		time.Sleep(100 * time.Millisecond)
	}
	fg, _, _ := procGetForegroundWindow.Call()
	return fg == hwnd
}

// WaitForWindowForeground waits up to waitMs for a visible window whose title contains titleSubstring and brings
// it to the foreground (a program just started may not have its window or final title yet). Returns found, active.
func WaitForWindowForeground(titleSubstring string, waitMs int) (bool, bool) {
	deadline := time.Now().Add(time.Duration(waitMs) * time.Millisecond)
	for {
		if hwnd := findVisibleWindow(titleSubstring); hwnd != 0 {
			return true, activateWindow(hwnd)
		}
		if time.Now().After(deadline) {
			return false, false
		}
		time.Sleep(200 * time.Millisecond)
	}
}

// findVisibleWindow returns the first visible top-level window whose title contains titleSubstring (case-insensitive).
func findVisibleWindow(titleSubstring string) uintptr {
	if strings.TrimSpace(titleSubstring) == "" {
		return 0
	}
	lowerTarget := strings.ToLower(titleSubstring)
	var foundHwnd uintptr
	cb := syscall.NewCallback(func(hwnd uintptr, lParam uintptr) uintptr {
		vis, _, _ := procIsWindowVisible.Call(hwnd)
		if vis == 0 {
			return 1
		}
		buf := make([]uint16, 512)
		length, _, _ := procGetWindowTextW.Call(hwnd, uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
		if length > 0 && strings.Contains(strings.ToLower(syscall.UTF16ToString(buf[:length])), lowerTarget) {
			foundHwnd = hwnd
			return 0
		}
		return 1
	})
	_, _, _ = procEnumWindows.Call(cb, 0)
	return foundHwnd
}

// IsProcessElevated checks if current process runs in an Administrator security token context.
func IsProcessElevated() bool {
	var token syscall.Token
	h := syscall.Handle(os.Getpid())
	err := syscall.OpenProcessToken(h, syscall.TOKEN_QUERY, &token)
	if err != nil {
		// Fallback check using net session probe
		return false
	}
	defer func() {
		_ = token.Close()
	}()

	var elevated uint32
	var returnedLen uint32
	// TokenElevation class = 20
	err = syscall.GetTokenInformation(token, 20, (*byte)(unsafe.Pointer(&elevated)), uint32(unsafe.Sizeof(elevated)), &returnedLen)
	if err != nil {
		return false
	}
	return elevated != 0
}

// FormatExecutionError formats command execution error with context.
func FormatExecutionError(context string, err error) error {
	return fmt.Errorf("%s: %w", context, err)
}
