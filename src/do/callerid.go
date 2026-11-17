/*
================================================================================
FILE NAME      : callerid.go
PACKAGE        : main
DESCRIPTION    : Slow-path caller identification for the verify-legal-elevation helper
                 (CRP-343 D4): loopback connection -> PID -> command line -> parent chain.
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-17
VERSION        : 10.2.4
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.4: CRP-343 initial implementation.
================================================================================
Implementation Choices (CRP-343 D4): used only when the intent-table fast path is
  inconclusive. The client PID comes from the OS TCP table (connection whose local port is
  the request's remote port), never from request fields. The chain is walked at most
  maxCallerDepth parents; the first process whose command line names a catalogued tool is
  the direct caller tool.
Caveats: in-process calls (pwsh "& script") are invisible at process level; the slow path
  sees the process that opened the connection.
================================================================================
*/

package main

import (
	"fmt"
	"net"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

const maxCallerDepth = 6

var procNtQueryInformationProcess = syscall.NewLazyDLL("ntdll.dll").NewProc("NtQueryInformationProcess")

type callerProcess struct {
	PID         uint32 `json:"pid"`
	ParentPID   uint32 `json:"parentPid"`
	Image       string `json:"image"`
	CommandLine string `json:"commandLine"`
}

// connectionPID returns the PID that owns the client side of a loopback connection to the daemon.
func connectionPID(remoteAddr string, serverPort int) (uint32, error) {
	_, portStr, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return 0, fmt.Errorf("remote address %q: %w", remoteAddr, err)
	}
	clientPort, err := strconv.Atoi(portStr)
	if err != nil {
		return 0, fmt.Errorf("remote port %q: %w", portStr, err)
	}
	var size uint32
	procGetExtendedTcpTable.Call(0, uintptr(unsafe.Pointer(&size)), 0, syscall.AF_INET, 5, 0) // TCP_TABLE_OWNER_PID_ALL
	if size == 0 {
		return 0, fmt.Errorf("tcp table size unavailable")
	}
	buf := make([]byte, size)
	if r, _, _ := procGetExtendedTcpTable.Call(uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&size)), 0, syscall.AF_INET, 5, 0); r != 0 {
		return 0, fmt.Errorf("GetExtendedTcpTable failed: %d", r)
	}
	n := *(*uint32)(unsafe.Pointer(&buf[0]))
	const rowSize = 24
	for i := uint32(0); i < n; i++ {
		off := 4 + i*rowSize
		if int(off+rowSize) > len(buf) {
			break
		}
		row := buf[off : off+rowSize]
		lp := netPort(*(*uint32)(unsafe.Pointer(&row[8])))
		rp := netPort(*(*uint32)(unsafe.Pointer(&row[16])))
		if lp == clientPort && rp == serverPort {
			return *(*uint32)(unsafe.Pointer(&row[20])), nil
		}
	}
	return 0, fmt.Errorf("no connection from port %d to %d", clientPort, serverPort)
}

func netPort(raw uint32) int {
	return int((raw&0xff)<<8 | (raw>>8)&0xff)
}

// processCommandLine reads the command line of pid (ProcessCommandLineInformation = 60).
func processCommandLine(pid uint32) (string, error) {
	h, err := syscall.OpenProcess(0x1000, false, pid) // PROCESS_QUERY_LIMITED_INFORMATION
	if err != nil {
		return "", fmt.Errorf("open process %d: %w", pid, err)
	}
	defer func() { _ = syscall.CloseHandle(h) }()
	var need uint32
	procNtQueryInformationProcess.Call(uintptr(h), 60, 0, 0, uintptr(unsafe.Pointer(&need)))
	if need == 0 {
		return "", fmt.Errorf("command line size of %d unavailable", pid)
	}
	buf := make([]byte, need)
	if st, _, _ := procNtQueryInformationProcess.Call(uintptr(h), 60, uintptr(unsafe.Pointer(&buf[0])), uintptr(need), uintptr(unsafe.Pointer(&need))); st != 0 {
		return "", fmt.Errorf("NtQueryInformationProcess(%d): status 0x%x", pid, st)
	}
	length := *(*uint16)(unsafe.Pointer(&buf[0]))
	ptr := *(*uintptr)(unsafe.Pointer(&buf[unsafe.Sizeof(uintptr(0))]))
	if length == 0 || ptr == 0 {
		return "", nil
	}
	// The string buffer lies inside buf (after the UNICODE_STRING header): read it by offset.
	base := uintptr(unsafe.Pointer(&buf[0]))
	if ptr < base || ptr+uintptr(length) > base+uintptr(len(buf)) {
		return "", fmt.Errorf("command line of %d outside the result buffer", pid)
	}
	off := int(ptr - base)
	chars := make([]uint16, int(length)/2)
	for i := range chars {
		chars[i] = uint16(buf[off+2*i]) | uint16(buf[off+2*i+1])<<8
	}
	return syscall.UTF16ToString(chars), nil
}

// parentPIDs maps every running PID to its parent PID.
func parentPIDs() (map[uint32]uint32, error) {
	snap, err := syscall.CreateToolhelp32Snapshot(syscall.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil, fmt.Errorf("process snapshot: %w", err)
	}
	defer func() { _ = syscall.CloseHandle(snap) }()
	m := map[uint32]uint32{}
	var pe syscall.ProcessEntry32
	pe.Size = uint32(unsafe.Sizeof(pe))
	for err = syscall.Process32First(snap, &pe); err == nil; err = syscall.Process32Next(snap, &pe) {
		m[pe.ProcessID] = pe.ParentProcessID
	}
	return m, nil
}

// callerChain returns the client process and its ancestors (at most maxCallerDepth).
func callerChain(remoteAddr string, serverPort int) ([]callerProcess, error) {
	pid, err := connectionPID(remoteAddr, serverPort)
	if err != nil {
		return nil, err
	}
	parents, err := parentPIDs()
	if err != nil {
		return nil, err
	}
	chain := make([]callerProcess, 0, maxCallerDepth)
	seen := map[uint32]bool{}
	for depth := 0; depth < maxCallerDepth && pid != 0 && !seen[pid]; depth++ {
		seen[pid] = true
		cp := callerProcess{PID: pid, ParentPID: parents[pid]}
		cp.Image, _ = processImage(pid)
		cp.CommandLine, _ = processCommandLine(pid)
		chain = append(chain, cp)
		pid = parents[pid]
	}
	return chain, nil
}

// directCallerTool returns the first catalogued tool named on the chain's command lines.
func directCallerTool(chain []callerProcess, gitRoot string, tools map[string]bool) (string, bool) {
	for i := range chain {
		for _, tok := range splitCommandLine(chain[i].CommandLine) {
			key := normalizeAtomPath(tok, gitRoot)
			if key == "" {
				continue
			}
			if admin, ok := tools[key]; ok {
				return key, admin
			}
		}
	}
	return "", false
}

// describeChain renders the chain for the log.
func describeChain(chain []callerProcess) string {
	parts := make([]string, 0, len(chain))
	for i := range chain {
		parts = append(parts, fmt.Sprintf("%d %s", chain[i].PID, strings.TrimSpace(chain[i].CommandLine)))
	}
	return strings.Join(parts, " <- ")
}
