/*
================================================================================
FILE NAME      : serverid.go
PACKAGE        : main
DESCRIPTION    : Client-side daemon identity check (CRP-343): the key is sent only when the
                 process listening on 127.0.0.1:<port> is this same do.exe binary.
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-17
VERSION        : 10.2.4
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.4: CRP-343 initial implementation (port-squatting guard).
================================================================================
Implementation Choices (CRP-343): the listener's PID comes from the OS TCP table
  (GetExtendedTcpTable, TCP_TABLE_OWNER_PID_LISTENER), not from the daemon's own /status
  answer, so a process squatting on the port cannot claim to be the daemon.
================================================================================
*/

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

var (
	modiphlpapi                = syscall.NewLazyDLL("iphlpapi.dll")
	procGetExtendedTcpTable    = modiphlpapi.NewProc("GetExtendedTcpTable")
	procQueryFullProcessImageW = modkernel32.NewProc("QueryFullProcessImageNameW")
)

// listenerPID returns the PID listening on 127.0.0.1 (or 0.0.0.0) at port.
func listenerPID(port int) (uint32, error) {
	var size uint32
	procGetExtendedTcpTable.Call(0, uintptr(unsafe.Pointer(&size)), 0, syscall.AF_INET, 3, 0)
	if size == 0 {
		return 0, fmt.Errorf("tcp table size unavailable")
	}
	buf := make([]byte, size)
	r, _, _ := procGetExtendedTcpTable.Call(uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&size)), 0, syscall.AF_INET, 3, 0)
	if r != 0 {
		return 0, fmt.Errorf("GetExtendedTcpTable failed: %d", r)
	}
	n := *(*uint32)(unsafe.Pointer(&buf[0]))
	const rowSize = 24 // MIB_TCPROW_OWNER_PID: state, localAddr, localPort, remoteAddr, remotePort, pid
	for i := uint32(0); i < n; i++ {
		off := 4 + i*rowSize
		if int(off+rowSize) > len(buf) {
			break
		}
		row := buf[off : off+rowSize]
		addr := *(*uint32)(unsafe.Pointer(&row[4]))
		rawPort := *(*uint32)(unsafe.Pointer(&row[8]))
		p := int((rawPort&0xff)<<8 | (rawPort>>8)&0xff)
		pid := *(*uint32)(unsafe.Pointer(&row[20]))
		if p == port && (addr == 0x0100007f || addr == 0) {
			return pid, nil
		}
	}
	return 0, fmt.Errorf("no listener on port %d", port)
}

// processImage returns the full image path of pid.
func processImage(pid uint32) (string, error) {
	h, err := syscall.OpenProcess(0x1000, false, pid) // PROCESS_QUERY_LIMITED_INFORMATION
	if err != nil {
		return "", fmt.Errorf("open process %d: %w", pid, err)
	}
	defer func() { _ = syscall.CloseHandle(h) }()
	buf := make([]uint16, 1024)
	size := uint32(len(buf))
	r, _, e := procQueryFullProcessImageW.Call(uintptr(h), 0, uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&size)))
	if r == 0 {
		return "", fmt.Errorf("query image of %d: %w", pid, e)
	}
	return syscall.UTF16ToString(buf[:size]), nil
}

// daemonIsGenuine reports whether the listener on port runs the same binary as this client.
func daemonIsGenuine(port int) (bool, string) {
	pid, err := listenerPID(port)
	if err != nil {
		return false, err.Error()
	}
	img, err := processImage(pid)
	if err != nil {
		return false, err.Error()
	}
	self, err := os.Executable()
	if err != nil {
		return false, fmt.Sprintf("own executable unknown: %v", err)
	}
	if s, err := filepath.EvalSymlinks(self); err == nil {
		self = s
	}
	if !strings.EqualFold(filepath.Clean(img), filepath.Clean(self)) {
		return false, fmt.Sprintf("listener PID %d runs %s, not %s", pid, img, self)
	}
	return true, ""
}
