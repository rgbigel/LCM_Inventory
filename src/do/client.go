/*
================================================================================
FILE NAME      : client.go
PACKAGE        : main
DESCRIPTION    : CLI Client dispatcher connecting to the Port 9876 LCM Desktop Daemon.
AUTHOR         : Rolf
DATE CREATED   : 2026-11-11
LAST MODIFIED  : 2026-11-19
VERSION        : 10.2.8
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-11 - 10.0.0: Initial implementation.
2026-11-17 - 10.2.4: CRP-343 sends the daemon key (X-LCM-Key) after verifying that the
                     port listener is this same do.exe binary (serverid.go).
2026-11-19 - 10.2.8: CRP-361 DO-Little: routeDecision picks the local path (caller's own token) or
                     the daemon; -explain shows the route without executing, -daemon forces it.
                     GetGitRoot derives the root from the binary location (no fixed D: path).
================================================================================
*/

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// RunClient executes the CLI client workflow, parsing flags and dispatching HTTP request to port 9876.
func RunClient(args []string) (int, error) {
	port := GetDaemonPort()
	daemonURL := fmt.Sprintf("http://127.0.0.1:%d", port)

	var (
		elevated    bool
		syncMode    bool
		noExit      bool
		forceDaemon bool
		explain     bool
		timeoutSec  int = 30
		cmdParts    []string
	)

	// Custom flag parsing to allow natural syntax: do "es.exe query" -sync or do -sync Get-Date
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch strings.ToLower(arg) {
		case "-elevated", "--elevated", "-e":
			elevated = true
		case "-sync", "--sync", "-s":
			syncMode = true
		case "-noexit", "--noexit", "-k":
			noExit = true
		case "-daemon", "--daemon":
			forceDaemon = true
		case "-explain", "--explain":
			explain = true
		case "-timeout", "--timeout", "-t":
			if i+1 < len(args) {
				t, err := strconv.Atoi(args[i+1])
				if err == nil && t > 0 {
					timeoutSec = t
					i++
				}
			}
		case "-command", "--command", "-c":
			if i+1 < len(args) {
				cmdParts = append(cmdParts, args[i+1])
				i++
			}
		case "status", "-status", "--status", "ping", "-ping":
			return CheckDaemonStatus(daemonURL)
		case "log", "logs", "stats":
			return ShowLastLog()
		case "-h", "--help", "-help", "help", "/?":
			PrintUsage()
			return 0, nil
		case "-v", "--version", "-version", "version":
			fmt.Println("LCM DO Client/Daemon v10.2.8 (Go 1.22+ native single binary)")
			return 0, nil
		default:
			cmdParts = append(cmdParts, arg)
		}
	}

	commandStr := strings.TrimSpace(strings.Join(cmdParts, " "))
	if commandStr == "" {
		PrintUsage()
		return 1, fmt.Errorf("no command provided")
	}

	// CRP-361 T2: local or daemon.
	route, reason := routeDecision(clientRouteInput(commandStr, forceDaemon, elevated, syncMode, noExit, GetGitRoot()))
	if explain {
		fmt.Printf("route: %s (%s)\n", route, reason)
		return 0, nil
	}
	if route == routeLocal {
		return runLocal(commandStr, syncMode, noExit, timeoutSec, reason)
	}

	reqPayload := ExecuteRequest{
		Command:     commandStr,
		Elevated:    elevated,
		Sync:        syncMode,
		NoExit:      noExit,
		WindowStyle: "Normal",
		TimeoutMs:   timeoutSec * 1000,
	}

	bodyBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return 1, fmt.Errorf("failed to serialize request: %w", err)
	}

	clientTimeout := time.Duration(timeoutSec+10) * time.Second
	client := &http.Client{Timeout: clientTimeout}

	ctx, cancel := context.WithTimeout(context.Background(), clientTimeout)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, daemonURL+"/execute", bytes.NewReader(bodyBytes))
	if err != nil {
		return 1, fmt.Errorf("failed to create HTTP request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if genuine, why := daemonIsGenuine(port); genuine { // CRP-343
		if k := readClientKey(); k != "" {
			httpReq.Header.Set(keyHeader, k)
		}
	} else {
		fmt.Fprintf(os.Stderr, "[DO] daemon key withheld: %s\n", why)
	}

	resp, err := client.Do(httpReq)
	if err != nil {
		return 1, fmt.Errorf("this call needs the daemon (%s), but the desktop daemon on port %d is unreachable (%w); it does not run locally instead", reason, port, err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return 1, fmt.Errorf("failed to read response: %w", err)
	}

	var execResp ExecuteResponse
	err = json.Unmarshal(respBytes, &execResp)
	if err != nil {
		// Output raw text if JSON unmarshaling fails
		fmt.Println(string(respBytes))
		return 0, nil
	}

	if syncMode {
		if execResp.Stdout != "" {
			_, _ = os.Stdout.WriteString(execResp.Stdout)
			if !strings.HasSuffix(execResp.Stdout, "\n") {
				_, _ = os.Stdout.WriteString("\n")
			}
		}
		if execResp.Stderr != "" {
			_, _ = os.Stderr.WriteString(execResp.Stderr)
			if !strings.HasSuffix(execResp.Stderr, "\n") {
				_, _ = os.Stderr.WriteString("\n")
			}
		}
		return execResp.ExitCode, nil
	}

	// Asynchronous dispatch receipt
	fmt.Printf("[DISPATCHED] Command: %s (Elevated: %t, NoExit: %t, Status: %s)\n",
		execResp.Command, execResp.Elevated, execResp.NoExit, execResp.Status)
	return 0, nil
}

// CheckDaemonStatus queries /status on port 9876 and prints diagnostic telemetry.
func CheckDaemonStatus(daemonURL string) (int, error) {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(daemonURL + "/status")
	if err != nil {
		fmt.Printf("[OFFLINE] No LCM Desktop Daemon responding at %s: %v\n", daemonURL, err)
		return 1, nil
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 1, fmt.Errorf("failed reading status response: %w", err)
	}

	var status StatusResponse
	if err := json.Unmarshal(body, &status); err != nil {
		fmt.Println(string(body))
		return 0, nil
	}

	fmt.Printf("LCM Desktop Daemon Status:\n")
	fmt.Printf("  Status    : %s\n", status.Status)
	fmt.Printf("  PID       : %d\n", status.Pid)
	fmt.Printf("  User      : %s\n", status.User)
	fmt.Printf("  Session ID: %d\n", status.SessionID)
	fmt.Printf("  Uptime    : %d sec\n", status.UptimeSec)
	fmt.Printf("  Memory    : %.2f MB\n", status.WorkingSetMB)
	fmt.Printf("  Port      : %d\n", status.Port)
	fmt.Printf("  Version   : %s\n", status.Version)
	return 0, nil
}

// ShowLastLog reads and prints the most recent action telemetry log.
func ShowLastLog() (int, error) {
	gitRoot := GetGitRoot()
	logPath := filepath.Join(gitRoot, "LCM_Inventory", "data", "logs", "do", "last_do.json")

	data, err := os.ReadFile(logPath)
	if err != nil {
		fmt.Printf("No recent DO telemetry found at %s\n", logPath)
		return 0, nil
	}

	var log ActionLog
	if err := json.Unmarshal(data, &log); err != nil {
		fmt.Println(string(data))
		return 0, nil
	}

	fmt.Println("=== LAST LCM DO EXECUTION TELEMETRY ===")
	fmt.Printf("Timestamp : %s\n", log.Timestamp)
	fmt.Printf("Command   : %s\n", log.Command)
	fmt.Printf("Status    : %s\n", log.Status)
	fmt.Printf("Exit Code : %d\n", log.ExitCode)
	fmt.Printf("Duration  : %d ms\n", log.DurationMs)
	fmt.Printf("Elevated  : %t\n", log.Elevated)
	if log.Stdout != "" {
		fmt.Printf("Stdout    :\n%s\n", log.Stdout)
	}
	if log.Stderr != "" {
		fmt.Printf("Stderr    :\n%s\n", log.Stderr)
	}
	return 0, nil
}

// GetDaemonPort discovers daemon port from environment or returns default 9876.
func GetDaemonPort() int {
	pStr := os.Getenv("LCM_DAEMON_PORT")
	if pStr != "" {
		if p, err := strconv.Atoi(pStr); err == nil && p > 0 {
			return p
		}
	}
	return 9876
}

// GetGitRoot resolves the root directory of the LCM workspace.
func GetGitRoot() string {
	root := os.Getenv("Git_Root")
	if root != "" && dirExists(root) {
		return root
	}
	// The git root is derived from this binary's location (<root>/LCM_Inventory/DoT/do.exe), never a fixed
	// drive path (operator 2026-11-19, CRP-253 sandboxing).
	if exe, err := os.Executable(); err == nil {
		candidate := filepath.Dir(filepath.Dir(filepath.Dir(exe)))
		if dirExists(filepath.Join(candidate, "LCM_Inventory")) {
			return candidate
		}
	}
	cwd, err := os.Getwd()
	if err == nil {
		return cwd
	}
	return "."
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// PrintUsage displays interactive help for the do tool.
func PrintUsage() {
	fmt.Println("==========================================================================")
	fmt.Println(" LCM DO / UNIFIED TOOL GATEWAY (do.exe v10.2.8)")
	fmt.Println("==========================================================================")
	fmt.Println("SYNOPSIS:")
	fmt.Println("  Unified execution gateway: simple calls run locally with the caller's rights,")
	fmt.Println("  elevation, de-elevation and windows without a desktop go to the Session 1 daemon (CRP-361).")
	fmt.Println("")
	fmt.Println("USAGE:")
	fmt.Println("  do <command> [-sync] [-elevated] [-noexit] [-timeout <sec>] [-daemon] [-explain]")
	fmt.Println("  do daemon [-port <port>]")
	fmt.Println("  do status")
	fmt.Println("  do log")
	fmt.Println("")
	fmt.Println("FLAGS:")
	fmt.Println("  -sync, -s      : Synchronous execution; captures and streams stdout/stderr.")
	fmt.Println("  -elevated, -e  : Dispatches with Administrator elevation onto Session 1 desktop.")
	fmt.Println("  -noexit, -k    : Keeps console window open upon completion.")
	fmt.Println("  -timeout, -t   : Execution timeout in seconds (default: 30).")
	fmt.Println("  -daemon        : Always use the daemon (no local path).")
	fmt.Println("  -explain       : Print the route (local or daemon) and its reason; execute nothing.")
	fmt.Println("==========================================================================")
}
