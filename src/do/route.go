/*
================================================================================
FILE NAME      : route.go
PACKAGE        : main
DESCRIPTION    : DO-Little (CRP-361): decides whether a do.exe call runs locally in the
                 client or through the desktop daemon, and runs the local path.
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-19
LAST MODIFIED  : 2026-11-19
VERSION        : 10.2.8
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-19 - 10.2.8: CRP-361 segment 1: routeDecision (T2), local path with the caller's
                     own token (T3), one log format for both paths (T4, log part).
================================================================================
Implementation Choices (CRP-361):
  - routeDecision is pure and exists once; client and daemon are the same binary, so the
    "one decision function" invariant holds by construction. It reuses the CRP-343 policy
    (loadPolicy / namedAtoms): any command naming an elevated atom goes to the daemon,
    which alone decides elevation (T3).
  - The local path runs with the client's own token, i.e. exactly the caller's rights;
    it never elevates and never de-elevates. An elevated caller therefore always goes to
    the daemon, which starts non-elevated work with the explorer token.
  - "Needs a window" = asynchronous dispatch (new console or GUI program) or -noexit; a
    synchronous call captures its output and needs no window, so it runs locally even in
    a session without a desktop (session 0).
  - Daemon-only cases never fall back to the local path when the daemon is down; the
    client reports the reason instead.
Caveats: intent call statistics (T4) are not updated yet; they follow the elimination of the
  JSON table copies (operator 2026-11-19).
================================================================================
*/

package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Route names (CRP-361 T2).
const (
	routeLocal  = "local"
	routeDaemon = "daemon"
)

// routeInput carries the facts routeDecision needs; filled by the client.
type routeInput struct {
	ForceDaemon    bool     // -daemon flag
	AskedElevated  bool     // -elevated flag
	ElevatedAtoms  []string // elevated atoms the command names (CRP-343 policy)
	CallerElevated bool     // the client process runs elevated
	NeedsWindow    bool     // asynchronous dispatch or -noexit
	HasDesktop     bool     // the client runs in an interactive session (not session 0)
	FromBrowser    bool     // request originates from a browser page (daemon side only)
}

// routeDecision implements the CRP-361 T2 table. Pure, so every row is unit-tested.
func routeDecision(in routeInput) (string, string) {
	switch {
	case in.FromBrowser:
		return routeDaemon, "request from a browser page"
	case in.ForceDaemon:
		return routeDaemon, "-daemon requested"
	case len(in.ElevatedAtoms) > 0:
		return routeDaemon, "command names the elevated atom " + strings.Join(in.ElevatedAtoms, ", ") + " (the daemon decides elevation)"
	case in.AskedElevated:
		return routeDaemon, "-elevated requested (the daemon decides elevation)"
	case in.CallerElevated:
		return routeDaemon, "elevated caller starts non-elevated work (the daemon de-elevates with the explorer token)"
	case in.NeedsWindow && !in.HasDesktop:
		return routeDaemon, "caller without a desktop needs a window"
	default:
		return routeLocal, "same rights as the caller, own desktop or no window needed"
	}
}

// clientRouteInput collects the routing facts for one client call.
func clientRouteInput(cmd string, forceDaemon, elevated, syncMode, noExit bool, gitRoot string) routeInput {
	atoms, _ := namedAtoms(cmd, gitRoot, loadPolicy(gitRoot))
	return routeInput{
		ForceDaemon:    forceDaemon,
		AskedElevated:  elevated,
		ElevatedAtoms:  atoms,
		CallerElevated: IsProcessElevated(),
		NeedsWindow:    !syncMode || noExit,
		HasDesktop:     GetCurrentSessionID() != 0,
	}
}

// clientCaller describes the client's caller for the log: parent process image and PID.
func clientCaller() string {
	ppid := os.Getppid()
	image, err := processImage(uint32(ppid))
	if err != nil || image == "" {
		return fmt.Sprintf("cli (parent pid %d)", ppid)
	}
	return fmt.Sprintf("cli %s (pid %d)", filepath.Base(image), ppid)
}

// runLocal executes the command in the client with the caller's own token (CRP-361 T3) and
// records it in the shared log format (T4).
func runLocal(cmdStr string, syncMode, noExit bool, timeoutSec int, reason string) (int, error) {
	gitRoot := GetGitRoot()
	caller := clientCaller()
	if syncMode {
		timeout := time.Duration(timeoutSec) * time.Second
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		exitCode, stdout, stderr, durMs := executeSynchronous(ctx, cmdStr, gitRoot, true, timeout)
		status := "COMPLETED"
		if exitCode != 0 {
			status = "ERROR"
		}
		recordActionLog(ActionLog{
			Timestamp: time.Now().Format("2006-01-02 15:04:05"), Command: cmdStr, ExitCode: exitCode,
			DurationMs: durMs, Status: status, Elevated: false, Stdout: stdout, Stderr: stderr,
			Path: routeLocal, Caller: caller, Decision: reason,
		})
		if stdout != "" {
			_, _ = os.Stdout.WriteString(stdout)
			if !strings.HasSuffix(stdout, "\n") {
				_, _ = os.Stdout.WriteString("\n")
			}
		}
		if stderr != "" {
			_, _ = os.Stderr.WriteString(stderr)
			if !strings.HasSuffix(stderr, "\n") {
				_, _ = os.Stderr.WriteString("\n")
			}
		}
		return exitCode, nil
	}
	start := time.Now()
	if _, err := executeAsynchronous(cmdStr, true, noExit, "Normal", gitRoot); err != nil {
		recordActionLog(ActionLog{
			Timestamp: time.Now().Format("2006-01-02 15:04:05"), Command: cmdStr, ExitCode: 1,
			DurationMs: time.Since(start).Milliseconds(), Status: "ERROR", Stderr: err.Error(),
			Path: routeLocal, Caller: caller, Decision: reason,
		})
		return 1, fmt.Errorf("local dispatch: %w", err)
	}
	recordActionLog(ActionLog{
		Timestamp: time.Now().Format("2006-01-02 15:04:05"), Command: cmdStr, Status: "DISPATCHED",
		DurationMs: time.Since(start).Milliseconds(), Path: routeLocal, Caller: caller, Decision: reason,
	})
	fmt.Printf("[DISPATCHED] Command: %s (Elevated: false, NoExit: %t, Status: DISPATCHED, Path: local)\n", cmdStr, noExit)
	return 0, nil
}
