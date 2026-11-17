/*
================================================================================
FILE NAME      : auth.go
PACKAGE        : main
DESCRIPTION    : Caller authentication for the DO daemon (CRP-343, decision D2 A):
                 per-boot key file, key check on state-changing routes, key injection
                 into the daemon's own HTML pages.
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
Implementation Choices (CRP-343):
  - The key is 32 random bytes (hex), regenerated at every daemon start and written to
    %LOCALAPPDATA%\LCM\do.key (per-user profile ACL). A web page cannot read files, so it
    cannot obtain the key; local processes of the operator account can, which is intended.
  - Browser requests (Origin or Sec-Fetch-* present) without the key are refused (401).
    Non-browser local requests without the key are accepted as "unauthenticated local
    caller" during the transition and are never elevated; LCM_DO_REQUIRE_KEY=1 refuses them.
  - Pages served by the daemon get a small inline script that adds the key header to
    same-origin fetches; those HTML responses carry no Access-Control-Allow-Origin, so a
    foreign page cannot read the key out of them.
Caveats: the key file is readable by every process of the operator account (by design).
================================================================================
*/

package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// keyHeader is the request header that carries the daemon key.
const keyHeader = "X-LCM-Key"

type authContextKey struct{}

// daemonKey is the per-boot key; empty until initDaemonKey ran.
var daemonKey string

// keyFilePath returns %LOCALAPPDATA%\LCM\do.key.
func keyFilePath() string {
	base := os.Getenv("LOCALAPPDATA")
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, "LCM", "do.key")
}

// initDaemonKey creates a fresh key and writes it to the key file.
func initDaemonKey() error {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Errorf("generate daemon key: %w", err)
	}
	key := hex.EncodeToString(buf)
	path := keyFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return fmt.Errorf("create key directory: %w", err)
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(key), 0o600); err != nil {
		return fmt.Errorf("write key file: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		return fmt.Errorf("replace key file: %w", err)
	}
	daemonKey = key
	return nil
}

// readClientKey returns the key from the key file (client side), or "" when absent.
func readClientKey() string {
	data, err := os.ReadFile(keyFilePath())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// isBrowserRequest reports whether the request carries browser-only markers.
func isBrowserRequest(r *http.Request) bool {
	return r.Header.Get("Origin") != "" || r.Header.Get("Sec-Fetch-Site") != "" || r.Header.Get("Sec-Fetch-Mode") != ""
}

// hasValidKey compares the presented key in constant time.
func hasValidKey(r *http.Request) bool {
	presented := r.Header.Get(keyHeader)
	if daemonKey == "" || presented == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(presented), []byte(daemonKey)) == 1
}

// requireKeyEverywhere is true when LCM_DO_REQUIRE_KEY=1 (end of transition).
func requireKeyEverywhere() bool {
	return strings.TrimSpace(os.Getenv("LCM_DO_REQUIRE_KEY")) == "1"
}

// checkCaller returns (authenticated, status, reason); status 0 means the request may proceed.
func checkCaller(r *http.Request) (bool, int, string) {
	if hasValidKey(r) {
		return true, 0, ""
	}
	if isBrowserRequest(r) {
		return false, http.StatusUnauthorized, "CRP-343: browser request without a valid daemon key refused"
	}
	if requireKeyEverywhere() {
		return false, http.StatusUnauthorized, "CRP-343: request without a valid daemon key refused (LCM_DO_REQUIRE_KEY=1)"
	}
	return false, 0, ""
}

// requireCaller authenticates state-changing requests and stores the result in the context.
func requireCaller(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet, http.MethodHead, http.MethodOptions:
			next.ServeHTTP(w, r)
			return
		}
		authed, status, reason := checkCaller(r)
		if status != 0 {
			denyLogger(ActionLog{
				Timestamp: time.Now().Format("2006-01-02 15:04:05"),
				Command:   fmt.Sprintf("%s %s (origin=%q, claimed caller header=%q, key presented=%t)", r.Method, r.URL.Path, r.Header.Get("Origin"), r.Header.Get("X-LCM-Caller"), r.Header.Get(keyHeader) != ""),
				ExitCode:  status,
				Status:    "DENIED",
				Stderr:    reason,
			})
			writeJSON(w, status, map[string]string{"error": reason})
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), authContextKey{}, authed)))
	})
}

// isAuthenticated reports the requireCaller result for this request.
func isAuthenticated(r *http.Request) bool {
	v, ok := r.Context().Value(authContextKey{}).(bool)
	return ok && v
}

// injectKeyScript inserts the same-origin fetch key shim directly after the <head> tag.
func injectKeyScript(html string) string {
	if daemonKey == "" {
		return html
	}
	shim := "\n  <script>(function(){var k='" + daemonKey + "';var f=window.fetch;window.fetch=function(u,o){try{var s=(typeof u==='string')?u:((u&&u.url)||String(u));var a=new URL(s,location.href);if(a.origin===location.origin){o=o||{};var h=new Headers(o.headers||((u&&u.headers)||{}));h.set('" + keyHeader + "',k);o.headers=h;}}catch(e){}return f.call(this,u,o);};})();</script>"
	lower := strings.ToLower(html)
	headIdx := strings.Index(lower, "<head")
	if headIdx == -1 {
		return shim + html
	}
	closeIdx := strings.Index(html[headIdx:], ">")
	if closeIdx == -1 {
		return shim + html
	}
	pos := headIdx + closeIdx + 1
	return html[:pos] + shim + html[pos:]
}

// stripCORS removes cross-origin read permission from a response that carries the key.
func stripCORS(w http.ResponseWriter) {
	for _, h := range []string{"Access-Control-Allow-Origin", "Access-Control-Allow-Methods", "Access-Control-Allow-Headers", "Access-Control-Allow-Private-Network"} {
		w.Header().Del(h)
	}
}
