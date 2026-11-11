/*
================================================================================
FILE NAME      : daemon.go
PACKAGE        : main
DESCRIPTION    : HTTP daemon listener for Session 1 desktop execution and telemetry.
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
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	daemonStartTime time.Time
	daemonMux       *http.ServeMux
	daemonServer    *http.Server
	daemonLogLock   sync.Mutex
)

// RunDaemon starts the HTTP listener on the specified port.
func RunDaemon(port int) error {
	daemonStartTime = time.Now()
	addr := fmt.Sprintf("127.0.0.1:%d", port)

	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("failed to bind to %s: %w", addr, err)
	}

	daemonMux = http.NewServeMux()

	// Register endpoints
	daemonMux.HandleFunc("/", handleStatusOrPing)
	daemonMux.HandleFunc("/ping", handleStatusOrPing)
	daemonMux.HandleFunc("/status", handleStatusOrPing)
	daemonMux.HandleFunc("/api/ping", handleStatusOrPing)
	daemonMux.HandleFunc("/api/status", handleStatusOrPing)

	daemonMux.HandleFunc("/execute", handleExecute)
	daemonMux.HandleFunc("/api/execute", handleExecute)

	daemonMux.HandleFunc("/open", handleOpen)
	daemonMux.HandleFunc("/api/open", handleOpen)

	daemonMux.HandleFunc("/foreground", handleForeground)
	daemonMux.HandleFunc("/api/foreground", handleForeground)

	daemonMux.HandleFunc("/stop", handleStop)
	daemonMux.HandleFunc("/api/stop", handleStop)

	daemonMux.HandleFunc("/proposals", handleProposals)
	daemonMux.HandleFunc("/proposals.json", handleProposals)
	daemonMux.HandleFunc("/api/proposals", handleProposals)

	daemonMux.HandleFunc("/session_state", handleSessionState)
	daemonMux.HandleFunc("/api/session_state", handleSessionState)

	daemonMux.HandleFunc("/log", handleLog)
	daemonMux.HandleFunc("/action_log", handleLog)
	daemonMux.HandleFunc("/telemetry", handleLog)
	daemonMux.HandleFunc("/report_incident", handleLog)

	daemonMux.HandleFunc("/logs", handleGetLogs)
	daemonMux.HandleFunc("/action_logs", handleGetLogs)
	daemonMux.HandleFunc("/actions", handleGetLogs)

	daemonMux.HandleFunc("/open_editor", handleOpenEditor)
	daemonMux.HandleFunc("/edit", handleOpenEditor)

	daemonServer = &http.Server{
		Handler:      daemonMux,
		ReadTimeout:  120 * time.Second,
		WriteTimeout: 600 * time.Second,
	}

	fmt.Printf("[ONLINE] LCM DO Daemon listening on http://%s (PID: %d, Session: %d)\n",
		addr, os.Getpid(), GetCurrentSessionID())

	if err := daemonServer.Serve(listener); err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("daemon server error: %w", err)
	}

	return nil
}

func writeJSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
	}
}

func handleStatusOrPing(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	workingSetMB := float64(m.Sys) / (1024.0 * 1024.0)

	gitRoot := GetGitRoot()
	logPath := filepath.Join(gitRoot, "LCM_Inventory", "data", "logs", "do", "last_do.json")

	resp := StatusResponse{
		Status:           "ONLINE",
		Pid:              os.Getpid(),
		UptimeSec:        int64(time.Since(daemonStartTime).Seconds()),
		StandardDisplays: 1,
		User:             GetCurrentUsername(),
		WorkingSetMB:     workingSetMB,
		Version:          "10.2.0",
		SessionID:        GetCurrentSessionID(),
		LogFile:          logPath,
		Port:             GetDaemonPort(),
	}

	writeJSON(w, http.StatusOK, resp)
}

func handleExecute(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Failed reading body"})
		return
	}

	var req ExecuteRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON payload: " + err.Error()})
		return
	}

	cmdStr := strings.TrimSpace(req.Command)
	if cmdStr == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Missing command string"})
		return
	}

	gitRoot := GetGitRoot()

	// Synchronous execution branch
	if req.Sync {
		timeout := 60 * time.Second
		if req.TimeoutMs > 0 {
			timeout = time.Duration(req.TimeoutMs) * time.Millisecond
		}

		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()

		exitCode, stdout, stderr, durMs := executeSynchronous(ctx, cmdStr, gitRoot)

		status := "COMPLETED"
		if exitCode != 0 {
			status = "ERROR"
		}

		resp := ExecuteResponse{
			Status:      status,
			ExitCode:    exitCode,
			Stdout:      stdout,
			Stderr:      stderr,
			DurationMs:  durMs,
			Command:     cmdStr,
			Elevated:    req.Elevated,
			NoExit:      req.NoExit,
			WindowStyle: req.WindowStyle,
		}

		// Record persistent log
		recordActionLog(ActionLog{
			Timestamp:  time.Now().Format("2006-01-02 15:04:05"),
			Command:    cmdStr,
			ExitCode:   exitCode,
			DurationMs: durMs,
			Status:     status,
			Elevated:   req.Elevated,
			Stdout:     stdout,
			Stderr:     stderr,
		})

		writeJSON(w, http.StatusOK, resp)
		return
	}

	// Asynchronous dispatch branch
	directExe, err := executeAsynchronous(cmdStr, req.Elevated, req.NoExit, req.WindowStyle, gitRoot)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	resp := ExecuteResponse{
		Status:      "DISPATCHED",
		ExitCode:    0,
		Command:     cmdStr,
		Elevated:    req.Elevated,
		NoExit:      req.NoExit,
		WindowStyle: req.WindowStyle,
		DirectExe:   directExe,
	}

	recordActionLog(ActionLog{
		Timestamp:  time.Now().Format("2006-01-02 15:04:05"),
		Command:    cmdStr,
		ExitCode:   0,
		DurationMs: 0,
		Status:     "DISPATCHED",
		Elevated:   req.Elevated,
	})

	writeJSON(w, http.StatusOK, resp)
}

func executeSynchronous(ctx context.Context, cmdStr string, wsRoot string) (int, string, string, int64) {
	start := time.Now()

	var cmd *exec.Cmd
	trimmed := strings.TrimSpace(cmdStr)

	// Determine execution method:
	// If it contains PowerShell syntax, scripts, or variables:
	if isPowerShellCommand(trimmed) {
		cmd = exec.CommandContext(ctx, "pwsh.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", trimmed)
	} else {
		tokens := splitCommandLine(trimmed)
		if len(tokens) > 0 {
			exePath, err := exec.LookPath(tokens[0])
			if err == nil && !strings.ContainsAny(trimmed, "|&><") {
				// Direct execution for native executables without shell operators
				cmd = exec.CommandContext(ctx, exePath, tokens[1:]...)
			} else {
				// Use cmd.exe /c for built-ins, shell redirects, pipes
				cmd = exec.CommandContext(ctx, "cmd.exe", "/c", trimmed)
			}
		} else {
			cmd = exec.CommandContext(ctx, "cmd.exe", "/c", trimmed)
		}
	}

	cmd.Dir = wsRoot
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: createNoWindow,
	}

	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	runErr := cmd.Run()
	dur := time.Since(start).Milliseconds()

	exitCode := 0
	if runErr != nil {
		if exitErr, ok := runErr.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = 1
			if stderrBuf.Len() == 0 {
				stderrBuf.WriteString(runErr.Error())
			}
		}
	}

	return exitCode, stdoutBuf.String(), stderrBuf.String(), dur
}

func executeAsynchronous(cmdStr string, elevated bool, noExit bool, windowStyle string, wsRoot string) (string, error) {
	trimmed := strings.TrimSpace(cmdStr)

	// If direct executable execution without shell wrapping
	tokens := splitCommandLine(trimmed)
	if len(tokens) > 0 && strings.HasSuffix(strings.ToLower(tokens[0]), ".exe") && !elevated && !noExit {
		exePath, err := exec.LookPath(tokens[0])
		if err == nil {
			cmd := exec.Command(exePath, tokens[1:]...)
			cmd.Dir = wsRoot
			var flags uint32 = createNewConsole
			if strings.EqualFold(windowStyle, "Hidden") {
				flags = createNoWindow
			}
			cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: flags}
			if err := cmd.Start(); err != nil {
				return "", fmt.Errorf("failed starting %s: %w", exePath, err)
			}
			return exePath, nil
		}
	}

	var cmd *exec.Cmd
	if isPowerShellCommand(trimmed) {
		psArgs := []string{"-NoProfile", "-ExecutionPolicy", "Bypass"}
		if noExit {
			psArgs = append(psArgs, "-NoExit")
		}
		psArgs = append(psArgs, "-Command", trimmed)
		cmd = exec.Command("pwsh.exe", psArgs...)
	} else {
		cmdFlag := "/c"
		if noExit {
			cmdFlag = "/k"
		}
		cmd = exec.Command("cmd.exe", cmdFlag, trimmed)
	}

	cmd.Dir = wsRoot
	var flags uint32 = createNewConsole
	if strings.EqualFold(windowStyle, "Hidden") && !noExit {
		flags = createNoWindow
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: flags}

	if err := cmd.Start(); err != nil {
		return "", fmt.Errorf("failed asynchronous dispatch: %w", err)
	}

	return "", nil
}

func isPowerShellCommand(cmd string) bool {
	if strings.HasPrefix(cmd, "&") || strings.Contains(cmd, ".ps1") || strings.HasPrefix(cmd, "$") {
		return true
	}
	lower := strings.ToLower(cmd)
	if strings.Contains(lower, "get-") || strings.Contains(lower, "set-") ||
		strings.Contains(lower, "invoke-") || strings.Contains(lower, "test-") ||
		strings.Contains(lower, "new-") || strings.Contains(lower, "start-") ||
		strings.Contains(lower, "stop-") || strings.Contains(lower, "-file ") {
		return true
	}
	return false
}

func splitCommandLine(cmd string) []string {
	var args []string
	var current strings.Builder
	inQuote := false
	quoteChar := byte(0)

	for i := 0; i < len(cmd); i++ {
		c := cmd[i]
		if inQuote {
			if c == quoteChar {
				inQuote = false
			} else {
				current.WriteByte(c)
			}
		} else {
			if c == '"' || c == '\'' {
				inQuote = true
				quoteChar = c
			} else if c == ' ' || c == '\t' {
				if current.Len() > 0 {
					args = append(args, current.String())
					current.Reset()
				}
			} else {
				current.WriteByte(c)
			}
		}
	}
	if current.Len() > 0 {
		args = append(args, current.String())
	}
	return args
}

func handleOpen(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Failed reading body"})
		return
	}

	var req OpenRequest
	if err := json.Unmarshal(body, &req); err != nil {
		var altReq struct {
			URL string `json:"url"`
		}
		if errAlt := json.Unmarshal(body, &altReq); errAlt == nil && altReq.URL != "" {
			req.Target = altReq.URL
		} else {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON: " + err.Error()})
			return
		}
	}

	target := strings.TrimSpace(req.Target)
	if target == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Target cannot be empty"})
		return
	}

	// Launch target using Windows Shell
	cmd := exec.Command("cmd.exe", "/c", "start", "", target)
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNoWindow}
	if err := cmd.Start(); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to launch target: " + err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "OK",
		"target": target,
	})
}

func handleForeground(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Failed reading body"})
		return
	}

	var req ForegroundRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON: " + err.Error()})
		return
	}

	found := BringWindowToForeground(req.Title)
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "OK",
		"title":  req.Title,
		"found":  found,
	})
}

func handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "STOPPING"})

	go func() {
		time.Sleep(200 * time.Millisecond)
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if daemonServer != nil {
			_ = daemonServer.Shutdown(ctx)
		}
		os.Exit(0)
	}()
}

func handleProposals(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	gitRoot := GetGitRoot()
	propPath := filepath.Join(gitRoot, "LCM_Inventory", "data", "proposals", "proposals.json")

	data, err := os.ReadFile(propPath)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"last_proposal_id": 0,
			"proposals":        make([]interface{}, 0),
		})
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func handleSessionState(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	gitRoot := GetGitRoot()
	sessPath := filepath.Join(gitRoot, "LCM_Inventory", "data", "session_state", "active_session.json")

	data, err := os.ReadFile(sessPath)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"operating_mode":  "GOVERNED_IMPLEMENTATION",
			"active_gate":     "STEP_001",
			"search_radius":   2,
			"settled_facts":   make([]string, 0),
			"open_hypotheses": make([]string, 0),
			"circuit_breaker": false,
		})
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func handleLog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Failed reading body"})
		return
	}

	var log ActionLog
	if err := json.Unmarshal(body, &log); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid log payload: " + err.Error()})
		return
	}

	if log.Timestamp == "" {
		log.Timestamp = time.Now().Format("2006-01-02 15:04:05")
	}

	recordActionLog(log)
	writeJSON(w, http.StatusOK, map[string]string{"status": "OK"})
}

func handleGetLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	gitRoot := GetGitRoot()
	logPath := filepath.Join(gitRoot, "LCM_Inventory", "data", "logs", "do", "last_do.json")

	data, err := os.ReadFile(logPath)
	if err != nil {
		writeJSON(w, http.StatusOK, make([]interface{}, 0))
		return
	}

	var singleLog ActionLog
	if err := json.Unmarshal(data, &singleLog); err == nil {
		writeJSON(w, http.StatusOK, []ActionLog{singleLog})
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func handleOpenEditor(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "Method not allowed"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Failed reading body"})
		return
	}

	var req struct {
		FilePath string `json:"filePath"`
		Line     int    `json:"line"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload: " + err.Error()})
		return
	}

	target := req.FilePath
	if req.Line > 0 {
		target = fmt.Sprintf("%s:%d", target, req.Line)
	}

	cmd := exec.Command("cmd.exe", "/c", "code", "-g", target)
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNoWindow}
	_ = cmd.Start()

	writeJSON(w, http.StatusOK, map[string]string{"status": "OK", "target": target})
}

func recordActionLog(log ActionLog) {
	daemonLogLock.Lock()
	defer daemonLogLock.Unlock()

	gitRoot := GetGitRoot()
	logDir := filepath.Join(gitRoot, "LCM_Inventory", "data", "logs", "do")
	_ = os.MkdirAll(logDir, 0755)

	lastJSONPath := filepath.Join(logDir, "last_do.json")
	if bytes, err := json.MarshalIndent(log, "", "  "); err == nil {
		_ = os.WriteFile(lastJSONPath, bytes, 0644)
	}

	activityLogPath := filepath.Join(logDir, "do_activity.log")
	f, err := os.OpenFile(activityLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err == nil {
		defer func() {
			_ = f.Close()
		}()
		line := fmt.Sprintf("[%s] %s | Status: %s | ExitCode: %d | Duration: %dms | Elevated: %t\n",
			log.Timestamp, log.Command, log.Status, log.ExitCode, log.DurationMs, log.Elevated)
		_, _ = f.WriteString(line)
	}
}
