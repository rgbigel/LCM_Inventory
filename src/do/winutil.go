/*
================================================================================
FILE NAME      : winutil.go
PACKAGE        : main
DESCRIPTION    : Windows platform utilities, process attributes, and Win32 interop.
AUTHOR         : Rolf
DATE CREATED   : 2026-11-11
LAST MODIFIED  : 2026-11-11
VERSION        : 10.2.0
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-11 - 10.0.0: Initial implementation.
================================================================================
*/

package main

import (
	"fmt"
	"os"
	"os/user"
	"strings"
	"syscall"
	"unsafe"
)

var (
	modkernel32               = syscall.NewLazyDLL("kernel32.dll")
	moduser32                 = syscall.NewLazyDLL("user32.dll")
	procProcessIdToSessionId  = modkernel32.NewProc("ProcessIdToSessionId")
	procGetConsoleWindow      = modkernel32.NewProc("GetConsoleWindow")
	procSetForegroundWindow   = moduser32.NewProc("SetForegroundWindow")
	procShowWindow            = moduser32.NewProc("ShowWindow")
	procEnumWindows           = moduser32.NewProc("EnumWindows")
	procGetWindowTextW        = moduser32.NewProc("GetWindowTextW")
	procIsWindowVisible       = moduser32.NewProc("IsWindowVisible")
)

const (
	swRestore             = 9
	swShow                = 5
	createNoWindow        = 0x08000000
	createNewConsole      = 0x00000010
	detachedProcess       = 0x00000008
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
		procShowWindow.Call(foundHwnd, uintptr(swRestore))
		procSetForegroundWindow.Call(foundHwnd)
		return true
	}
	return false
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
