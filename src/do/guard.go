/*
================================================================================
FILE NAME      : guard.go
PACKAGE        : main
DESCRIPTION    : Request guard for state-changing daemon routes (BUG-347): refuses
                 browser requests from foreign origins and non-JSON request bodies.
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-17
VERSION        : 10.2.3
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.3: BUG-347 initial implementation. The Go port of the daemon
                     (2026-11-11) executed every POST to /execute and /action
                     without any caller check; a preflight-free cross-site POST
                     from a local browser page could run commands elevated.
================================================================================
*/

package main

import (
	"fmt"
	"mime"
	"net/http"
	"strings"
	"time"
)

// daemonPort is the port the daemon listens on; set by RunDaemon, used for the origin allow-list.
var daemonPort = 9876

// denyLogger records a refused request; replaced in tests to keep the live log untouched.
var denyLogger = recordActionLog

// guardMutations wraps the daemon mux. Safe methods (GET, HEAD, OPTIONS) pass unchanged;
// every other request must pass checkMutationRequest, otherwise it is refused and logged.
// Implementation Choices (BUG-347): one guard in front of the whole mux, so routes added later are
// covered automatically; non-browser callers (do.exe, PowerShell) send no Origin and are unaffected.
func guardMutations(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet, http.MethodHead, http.MethodOptions:
			next.ServeHTTP(w, r)
			return
		}
		status, reason := checkMutationRequest(r, daemonPort)
		if status != 0 {
			denyLogger(ActionLog{
				Timestamp: time.Now().Format("2006-01-02 15:04:05"),
				Command:   fmt.Sprintf("%s %s (origin=%q, sec-fetch-site=%q, content-type=%q)", r.Method, r.URL.Path, r.Header.Get("Origin"), r.Header.Get("Sec-Fetch-Site"), r.Header.Get("Content-Type")),
				ExitCode:  status,
				Status:    "DENIED",
				Stderr:    reason,
			})
			writeJSON(w, status, map[string]string{"error": reason})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// checkMutationRequest returns (0, "") when the request may proceed, otherwise the HTTP status and reason.
func checkMutationRequest(r *http.Request, port int) (int, string) {
	origin := strings.TrimSpace(r.Header.Get("Origin"))
	if origin != "" && !isAllowedOrigin(origin, port) {
		return http.StatusForbidden, fmt.Sprintf("BUG-347: request from origin %q refused; only the daemon's own pages may post", origin)
	}
	if strings.EqualFold(strings.TrimSpace(r.Header.Get("Sec-Fetch-Site")), "cross-site") {
		return http.StatusForbidden, "BUG-347: cross-site browser request refused"
	}
	if requestHasBody(r) {
		mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
		if err != nil || !strings.EqualFold(mediaType, "application/json") {
			return http.StatusUnsupportedMediaType, "BUG-347: request body must be sent as Content-Type application/json"
		}
	}
	return 0, ""
}

// isAllowedOrigin accepts only the daemon's own origins (pages served from 127.0.0.1 / localhost on its port).
func isAllowedOrigin(origin string, port int) bool {
	for _, allowed := range []string{
		fmt.Sprintf("http://127.0.0.1:%d", port),
		fmt.Sprintf("http://localhost:%d", port),
	} {
		if strings.EqualFold(origin, allowed) {
			return true
		}
	}
	return false
}

// requestHasBody reports whether the request carries a body (known length > 0, or unknown/chunked length).
func requestHasBody(r *http.Request) bool {
	return r.ContentLength > 0 || r.ContentLength < 0
}
