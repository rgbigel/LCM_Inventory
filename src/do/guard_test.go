/*
================================================================================
FILE NAME      : guard_test.go
PACKAGE        : main
DESCRIPTION    : Unit tests for the BUG-347 request guard (no network, no live log writes).
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-17
VERSION        : 10.2.3
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.3: BUG-347 initial tests.
================================================================================
*/

package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGuardMutations(t *testing.T) {
	denied := 0
	denyLogger = func(ActionLog) { denied++ }
	defer func() { denyLogger = recordActionLog }()

	reached := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reached = true
		w.WriteHeader(http.StatusOK)
	})
	handler := guardMutations(next)

	cases := []struct {
		name        string
		method      string
		origin      string
		fetchSite   string
		contentType string
		body        string
		wantStatus  int
		wantReached bool
	}{
		{"local tool JSON without origin", http.MethodPost, "", "", "application/json", `{"command":"echo"}`, http.StatusOK, true},
		{"own page JSON", http.MethodPost, "http://127.0.0.1:9876", "same-origin", "application/json; charset=utf-8", `{"command":"echo"}`, http.StatusOK, true},
		{"own page via localhost", http.MethodPost, "http://LOCALHOST:9876", "same-origin", "application/json", `{}`, http.StatusOK, true},
		{"stop without body", http.MethodPost, "", "", "", "", http.StatusOK, true},
		{"foreign page text/plain", http.MethodPost, "https://evil.example", "cross-site", "text/plain", `{"command":"calc"}`, http.StatusForbidden, false},
		{"foreign page without body", http.MethodPost, "https://evil.example", "cross-site", "", "", http.StatusForbidden, false},
		{"null origin (file or sandbox)", http.MethodPost, "null", "cross-site", "application/json", `{}`, http.StatusForbidden, false},
		{"other local port", http.MethodPost, "http://127.0.0.1:8080", "same-site", "application/json", `{}`, http.StatusForbidden, false},
		{"cross-site marker without origin", http.MethodPost, "", "cross-site", "application/json", `{}`, http.StatusForbidden, false},
		{"form post without origin", http.MethodPost, "", "", "application/x-www-form-urlencoded", "command=calc", http.StatusUnsupportedMediaType, false},
		{"text/plain without origin", http.MethodPost, "", "", "text/plain", `{"command":"calc"}`, http.StatusUnsupportedMediaType, false},
		{"GET from foreign page passes (read-only routes)", http.MethodGet, "https://evil.example", "cross-site", "", "", http.StatusOK, true},
		{"OPTIONS passes to route handler", http.MethodOptions, "https://evil.example", "cross-site", "", "", http.StatusOK, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			reached = false
			req := httptest.NewRequest(tc.method, "/execute", strings.NewReader(tc.body))
			if tc.body == "" {
				req.ContentLength = 0
			}
			if tc.origin != "" {
				req.Header.Set("Origin", tc.origin)
			}
			if tc.fetchSite != "" {
				req.Header.Set("Sec-Fetch-Site", tc.fetchSite)
			}
			if tc.contentType != "" {
				req.Header.Set("Content-Type", tc.contentType)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			if rec.Code != tc.wantStatus {
				t.Fatalf("status = %d, want %d (body %s)", rec.Code, tc.wantStatus, rec.Body.String())
			}
			if reached != tc.wantReached {
				t.Fatalf("next handler reached = %t, want %t", reached, tc.wantReached)
			}
		})
	}
	if denied != 7 {
		t.Fatalf("denied log entries = %d, want 7", denied)
	}
}
