/*
================================================================================
FILE NAME      : elevation.go
PACKAGE        : main
DESCRIPTION    : Atom-level elevation decision (CRP-343, decision D3 A) and the
                 non-elevated launcher (decision D1 A: explorer token +
                 CreateProcessWithTokenW).
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-19
VERSION        : 10.2.7
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.4: CRP-343 initial implementation.
================================================================================
Implementation Choices (CRP-343):
  - The policy is LCM_Inventory/data/tools/elevation_policy.json, generated from tools.db by
    tools/Export-LcmElevationPolicy.py (the daemon has no SQLite driver); reloaded on change.
  - verifyLegalElevation (D3/D4): fast path = intent table (elevated atom of an admin tool,
    caller authenticated); slow path only when inconclusive (several atoms, missing parameter
    switch, -elevated without atom): the direct caller tool on the process chain must have
    tools.admin = 1. The client's -elevated flag alone grants nothing.
  - Everything else runs with the token of the operator's explorer.exe (medium integrity,
    Session 1 desktop). Without an explorer token the request fails; there is no silent
    elevated fallback.
Caveats: verified 2026-11-17 by probe: CreateProcessAsUser with the explorer token fails
  (privilege not held) and the linked token cannot be made primary; CreateProcessWithTokenW
  works and yields Medium Mandatory Level.
2026-11-19 - 10.2.7: CRP-343 segment 2: tools.admin levels 0..3; an atom is legal only for an owner of level 3; slow-path caller decision (callerDecision): level 3, or level 2 with every requested atom in its list.
================================================================================
*/

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

type policyAtom struct {
	Script     string   `json:"script"`
	Executable string   `json:"executable"`
	IntentKeys []string `json:"intent_keys"`
	Parameters string   `json:"parameters"`
	ToolAdmin  int      `json:"tool_admin"`
}

type elevationPolicy struct {
	GeneratedAt   string              `json:"generated_at"`
	ElevatedAtoms []policyAtom        `json:"elevated_atoms"`
	Tools         map[string]int      `json:"tools"`
	AllowedAtoms  map[string][]string `json:"allowed_atoms"`
}

// Admin levels of tools.admin (CRP-343 segment 2).
const (
	adminTBD        = 0
	adminGranted    = 1
	adminControlled = 2
	adminFull       = 3
)

// loadedPolicy is the normalized view of elevation_policy.json.
type loadedPolicy struct {
	Atoms   map[string]string          // normalized script -> required parameter switch ("" = none)
	Tools   map[string]int             // normalized tool path -> admin level 0..3
	Allowed map[string]map[string]bool // normalized controlled tool path -> normalized atom scripts it may call
}

func newLoadedPolicy() *loadedPolicy {
	return &loadedPolicy{Atoms: map[string]string{}, Tools: map[string]int{}, Allowed: map[string]map[string]bool{}}
}

var (
	policyLock    sync.Mutex
	policyModTime time.Time
	policyCache   *loadedPolicy
)

var atomExtensions = []string{".ps1", ".psm1", ".cmd", ".bat", ".reg", ".py"}

func normalizeAtomPath(p string, gitRoot string) string {
	p = strings.Trim(strings.TrimSpace(p), `"'`)
	if p == "" {
		return ""
	}
	if filepath.IsAbs(p) {
		if rel, err := filepath.Rel(gitRoot, p); err == nil && !strings.HasPrefix(rel, "..") {
			p = rel
		} else {
			return ""
		}
	}
	p = strings.ToLower(filepath.ToSlash(p))
	return strings.TrimPrefix(p, "./")
}

// loadPolicy returns the normalized policy, reloading it when the file changed.
func loadPolicy(gitRoot string) *loadedPolicy {
	path := filepath.Join(gitRoot, "LCM_Inventory", "data", "tools", "elevation_policy.json")
	policyLock.Lock()
	defer policyLock.Unlock()
	fi, err := os.Stat(path)
	if err != nil {
		policyCache = newLoadedPolicy()
		return policyCache
	}
	if policyCache != nil && fi.ModTime().Equal(policyModTime) {
		return policyCache
	}
	lp := newLoadedPolicy()
	if data, err := os.ReadFile(path); err == nil {
		var pol elevationPolicy
		if err := json.Unmarshal(data, &pol); err == nil {
			byIntent := map[string]string{}
			for i := range pol.ElevatedAtoms {
				a := &pol.ElevatedAtoms[i]
				if a.ToolAdmin != adminFull { // catalog error: an elevated atom of a tool below level 3 is never elevated
					continue
				}
				if key := normalizeAtomPath(a.Script, gitRoot); key != "" {
					lp.Atoms[key] = strings.ToLower(strings.TrimSpace(a.Parameters))
					for _, ik := range a.IntentKeys {
						byIntent[strings.ToLower(ik)] = key
					}
				}
			}
			for t, level := range pol.Tools {
				if key := normalizeAtomPath(t, gitRoot); key != "" {
					lp.Tools[key] = level
				}
			}
			for t, intents := range pol.AllowedAtoms {
				key := normalizeAtomPath(t, gitRoot)
				if key == "" {
					continue
				}
				set := map[string]bool{}
				for _, ik := range intents {
					if script, ok := byIntent[strings.ToLower(ik)]; ok {
						set[script] = true
					}
				}
				lp.Allowed[key] = set
			}
		}
	}
	policyCache = lp
	policyModTime = fi.ModTime()
	return lp
}

// namedAtoms returns the distinct elevated atoms the command names, and whether a required
// parameter switch of one of them is missing.
func namedAtoms(cmdStr string, gitRoot string, pol *loadedPolicy) ([]string, bool) {
	tokens := splitCommandLine(cmdStr)
	lowerTokens := make([]string, len(tokens))
	for i, t := range tokens {
		lowerTokens[i] = strings.ToLower(t)
	}
	seen := map[string]bool{}
	atoms := make([]string, 0, 2)
	switchMissing := false
	for _, tok := range tokens {
		lower := strings.ToLower(tok)
		for _, ext := range atomExtensions {
			if !strings.HasSuffix(lower, ext) {
				continue
			}
			key := normalizeAtomPath(tok, gitRoot)
			req, ok := pol.Atoms[key]
			if !ok || seen[key] {
				continue
			}
			seen[key] = true
			atoms = append(atoms, key)
			if req != "" {
				found := false
				for _, lt := range lowerTokens {
					if lt == req {
						found = true
					}
				}
				if !found {
					switchMissing = true
				}
			}
		}
	}
	return atoms, switchMissing
}

// resolveElevatedAtom returns the first elevated atom the command names (fast-path helper, tests).
func resolveElevatedAtom(cmdStr string, gitRoot string, policy map[string]string) (string, bool) {
	atoms, _ := namedAtoms(cmdStr, gitRoot, &loadedPolicy{Atoms: policy, Tools: map[string]int{}, Allowed: map[string]map[string]bool{}})
	if len(atoms) == 0 {
		return "", false
	}
	return atoms[0], true
}

// elevationRequest carries what the verify-legal-elevation helper needs.
type elevationRequest struct {
	Command       string
	Authenticated bool
	AskedElevated bool
	RemoteAddr    string
}

// elevationVerdict is the helper's answer (also returned by GET /api/elevation/verify).
type elevationVerdict struct {
	Elevate    bool   `json:"elevate"`
	Path       string `json:"path"`
	Reason     string `json:"reason"`
	CallerTool string `json:"callerTool,omitempty"`
	Chain      string `json:"chain,omitempty"`
}

// verifyLegalElevation implements CRP-343 D3/D4: fast path from the intent table; slow path
// (caller identification) only when the fast path is inconclusive.
func verifyLegalElevation(req elevationRequest, gitRoot string) elevationVerdict {
	pol := loadPolicy(gitRoot)
	atoms, switchMissing := namedAtoms(req.Command, gitRoot, pol)

	inconclusive := ""
	switch {
	case len(atoms) > 1:
		inconclusive = "command names several elevated atoms (" + strings.Join(atoms, ", ") + ")"
	case len(atoms) == 1 && switchMissing:
		inconclusive = "elevated atom " + atoms[0] + " is narrowed by a parameter switch that the command lacks"
	case len(atoms) == 0 && req.AskedElevated:
		inconclusive = "-elevated requested for a command that names no elevated atom"
	}

	if len(atoms) > 0 && isCompositeCommand(req.Command) {
		return elevationVerdict{Elevate: false, Path: "fast", Reason: "composite command: an elevated atom runs elevated only as a single invocation (no ;, |, &&, redirection, newline, $( or backtick): runs non-elevated"}
	}

	if inconclusive == "" {
		switch {
		case len(atoms) == 0:
			return elevationVerdict{Elevate: false, Path: "fast", Reason: "not an elevated atom: runs non-elevated"}
		case !req.Authenticated:
			return elevationVerdict{Elevate: false, Path: "fast", Reason: "elevated atom " + atoms[0] + " requested by an unauthenticated caller: runs non-elevated"}
		default:
			return elevationVerdict{Elevate: true, Path: "fast", Reason: "elevated atom " + atoms[0]}
		}
	}

	v := elevationVerdict{Elevate: false, Path: "slow", Reason: inconclusive}
	if !req.Authenticated {
		v.Reason += "; caller unauthenticated: runs non-elevated"
		return v
	}
	chain, err := callerChain(req.RemoteAddr, daemonPort)
	if err != nil {
		v.Reason += "; caller not identified (" + err.Error() + "): runs non-elevated"
		return v
	}
	v.Chain = describeChain(chain)
	tool, level := directCallerTool(chain, gitRoot, pol.Tools)
	v.CallerTool = tool
	elevate, why := callerDecision(tool, level, pol.Allowed[tool], atoms, switchMissing)
	v.Elevate = elevate
	v.Reason += "; " + why
	return v
}

// callerDecision applies the CRP-343 call table to the direct caller tool: level 3 may use any legal
// elevated atom; level 2 only atoms of its list; levels 0 and 1 none. Pure, so the table is unit-tested.
func callerDecision(tool string, level int, allowed map[string]bool, atoms []string, switchMissing bool) (bool, string) {
	switch {
	case tool == "":
		return false, "no catalogued caller tool on the process chain: runs non-elevated"
	case len(atoms) == 0 || switchMissing:
		return false, "caller tool " + tool + " requests no legal elevated atom: runs non-elevated"
	case level == adminFull:
		return true, "direct caller tool " + tool + " has level 3 (admin): elevated"
	case level == adminControlled:
		for _, a := range atoms {
			if !allowed[a] {
				return false, "direct caller tool " + tool + " is controlled and " + a + " is not in its atom list: runs non-elevated"
			}
		}
		return true, "direct caller tool " + tool + " is controlled and every requested atom is in its list: elevated"
	default:
		return false, fmt.Sprintf("direct caller tool %s has level %d: runs non-elevated", tool, level)
	}
}

var (
	modadvapi32        = syscall.NewLazyDLL("advapi32.dll")
	procDupTokenEx     = modadvapi32.NewProc("DuplicateTokenEx")
	procCPWithTokenW   = modadvapi32.NewProc("CreateProcessWithTokenW")
	procGetShellWindow = moduser32.NewProc("GetShellWindow")
	procGetWndThrPid   = moduser32.NewProc("GetWindowThreadProcessId")
	procTerminateProc  = modkernel32.NewProc("TerminateProcess")
)

// explorerPrimaryToken duplicates the primary token of the shell process (explorer.exe).
func explorerPrimaryToken() (syscall.Token, error) {
	hwnd, _, _ := procGetShellWindow.Call()
	if hwnd == 0 {
		return 0, fmt.Errorf("no shell window (explorer.exe not running)")
	}
	var pid uint32
	procGetWndThrPid.Call(hwnd, uintptr(unsafe.Pointer(&pid)))
	h, err := syscall.OpenProcess(0x1000, false, pid) // PROCESS_QUERY_LIMITED_INFORMATION
	if err != nil {
		return 0, fmt.Errorf("open shell process %d: %w", pid, err)
	}
	defer func() { _ = syscall.CloseHandle(h) }()
	var tok syscall.Token
	if err := syscall.OpenProcessToken(h, 0x0001|0x0002|0x0008, &tok); err != nil { // ASSIGN_PRIMARY|DUPLICATE|QUERY
		return 0, fmt.Errorf("open shell token: %w", err)
	}
	defer func() { _ = tok.Close() }()
	var prim syscall.Token
	r, _, e := procDupTokenEx.Call(uintptr(tok), 0x02000000, 0, 2, 1, uintptr(unsafe.Pointer(&prim))) // MAXIMUM_ALLOWED, SecurityImpersonation, TokenPrimary
	if r == 0 {
		return 0, fmt.Errorf("duplicate shell token: %w", e)
	}
	return prim, nil
}

// buildCommandLine quotes a program and its arguments for CreateProcess.
func buildCommandLine(program string, args []string) string {
	parts := make([]string, 0, len(args)+1)
	parts = append(parts, syscall.EscapeArg(program))
	for _, a := range args {
		parts = append(parts, syscall.EscapeArg(a))
	}
	return strings.Join(parts, " ")
}

func inheritableWriteFile(path string) (syscall.Handle, error) {
	p, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return 0, err
	}
	sa := syscall.SecurityAttributes{Length: uint32(unsafe.Sizeof(syscall.SecurityAttributes{})), InheritHandle: 1}
	return syscall.CreateFile(p, syscall.GENERIC_WRITE, syscall.FILE_SHARE_READ, &sa, syscall.CREATE_ALWAYS, syscall.FILE_ATTRIBUTE_NORMAL, 0)
}

// startUnelevated starts program+args with the explorer token. With capture, stdout/stderr go to
// temp files and the call waits up to timeout; otherwise it returns after the start.
func startUnelevated(program string, args []string, dir string, flags uint32, capture bool, timeout time.Duration) (int, string, string, error) {
	tok, err := explorerPrimaryToken()
	if err != nil {
		return 1, "", "", fmt.Errorf("non-elevated launch impossible: %w", err)
	}
	defer func() { _ = tok.Close() }()

	si := syscall.StartupInfo{Cb: uint32(unsafe.Sizeof(syscall.StartupInfo{}))}
	desk, _ := syscall.UTF16PtrFromString(`winsta0\default`)
	si.Desktop = desk
	var outPath, errPath string
	var hOut, hErr syscall.Handle
	if capture {
		stamp := fmt.Sprintf("%d-%d", os.Getpid(), time.Now().UnixNano())
		outPath = filepath.Join(os.TempDir(), "lcm-do-"+stamp+".out")
		errPath = filepath.Join(os.TempDir(), "lcm-do-"+stamp+".err")
		if hOut, err = inheritableWriteFile(outPath); err != nil {
			return 1, "", "", fmt.Errorf("stdout file: %w", err)
		}
		if hErr, err = inheritableWriteFile(errPath); err != nil {
			_ = syscall.CloseHandle(hOut)
			return 1, "", "", fmt.Errorf("stderr file: %w", err)
		}
		si.Flags = syscall.STARTF_USESTDHANDLES
		si.StdOutput = hOut
		si.StdErr = hErr
	}
	cl, err := syscall.UTF16PtrFromString(buildCommandLine(program, args))
	if err != nil {
		return 1, "", "", fmt.Errorf("command line: %w", err)
	}
	var wd *uint16
	if dir != "" {
		if wd, err = syscall.UTF16PtrFromString(dir); err != nil {
			return 1, "", "", fmt.Errorf("working directory: %w", err)
		}
	}
	var pi syscall.ProcessInformation
	r, _, e := procCPWithTokenW.Call(uintptr(tok), 0, 0, uintptr(unsafe.Pointer(cl)), uintptr(flags), 0, uintptr(unsafe.Pointer(wd)), uintptr(unsafe.Pointer(&si)), uintptr(unsafe.Pointer(&pi)))
	if capture {
		_ = syscall.CloseHandle(hOut)
		_ = syscall.CloseHandle(hErr)
	}
	if r == 0 {
		return 1, "", "", fmt.Errorf("CreateProcessWithTokenW: %w", e)
	}
	defer func() {
		_ = syscall.CloseHandle(pi.Process)
		_ = syscall.CloseHandle(pi.Thread)
	}()
	if !capture {
		return 0, "", "", nil
	}
	ms := uint32(syscall.INFINITE)
	if timeout > 0 {
		ms = uint32(timeout.Milliseconds())
	}
	ev, _ := syscall.WaitForSingleObject(pi.Process, ms)
	timedOut := ev == uint32(syscall.WAIT_TIMEOUT)
	if timedOut {
		procTerminateProc.Call(uintptr(pi.Process), 1)
		_, _ = syscall.WaitForSingleObject(pi.Process, 5000)
	}
	var code uint32
	_ = syscall.GetExitCodeProcess(pi.Process, &code)
	stdout, _ := os.ReadFile(outPath)
	stderr, _ := os.ReadFile(errPath)
	_ = os.Remove(outPath)
	_ = os.Remove(errPath)
	errText := string(stderr)
	if timedOut {
		errText += fmt.Sprintf("\n[DO] timed out after %s; process terminated", timeout)
	}
	return int(code), string(stdout), errText, nil
}

// handleElevationVerify answers GET /api/elevation/verify?command=...[&elevated=true] with the
// verdict the daemon would apply, without executing anything (CRP-343 D4 dry run).
func handleElevationVerify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}
	cmd := strings.TrimSpace(r.URL.Query().Get("command"))
	if cmd == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "query parameter 'command' is required"})
		return
	}
	verdict := verifyLegalElevation(elevationRequest{
		Command:       cmd,
		Authenticated: hasValidKey(r),
		AskedElevated: strings.EqualFold(r.URL.Query().Get("elevated"), "true"),
		RemoteAddr:    r.RemoteAddr,
	}, GetGitRoot())
	writeJSON(w, http.StatusOK, verdict)
}

// isCompositeCommand reports whether a command does more than one invocation (CRP-343): control
// operators outside single quotes, redirection, newlines, subexpressions or backticks anywhere, or
// '&' anywhere but as the leading call operator.
func isCompositeCommand(cmd string) bool {
	trimmed := strings.TrimSpace(cmd)
	if strings.Contains(trimmed, "$(") || strings.Contains(trimmed, "`") || strings.ContainsAny(trimmed, "\r\n") {
		return true
	}
	inSingle, inDouble := false, false
	for i := 0; i < len(trimmed); i++ {
		c := trimmed[i]
		switch {
		case c == '\'' && !inDouble:
			inSingle = !inSingle
		case c == '"' && !inSingle:
			inDouble = !inDouble
		case inSingle || inDouble:
			continue
		case c == ';' || c == '|' || c == '>' || c == '<':
			return true
		case c == '&' && i != 0:
			return true
		}
	}
	return false
}
