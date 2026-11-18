/*
================================================================================
FILE NAME      : auth_test.go
PACKAGE        : main
DESCRIPTION    : Tests for the CRP-343 caller key, page shim and elevation decision.
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-17
LAST MODIFIED  : 2026-11-17
VERSION        : 10.2.4
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-17 - 10.2.4: CRP-343 initial tests (no live log, no key file, no daemon).
================================================================================
*/

package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func withKey(t *testing.T, key string) {
	t.Helper()
	old := daemonKey
	daemonKey = key
	oldLogger := denyLogger
	denyLogger = func(ActionLog) {}
	t.Cleanup(func() { daemonKey = old; denyLogger = oldLogger })
}

func runCaller(r *http.Request) (int, bool) {
	authed := false
	h := requireCaller(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		authed = isAuthenticated(req)
		w.WriteHeader(http.StatusOK)
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)
	return rec.Code, authed
}

func TestCallerKey(t *testing.T) {
	withKey(t, "secret")
	t.Setenv("LCM_DO_REQUIRE_KEY", "")

	r := httptest.NewRequest(http.MethodPost, "/execute", strings.NewReader("{}"))
	r.Header.Set(keyHeader, "secret")
	if code, authed := runCaller(r); code != 200 || !authed {
		t.Fatalf("valid key: code %d authed %t", code, authed)
	}

	r = httptest.NewRequest(http.MethodPost, "/execute", strings.NewReader("{}"))
	r.Header.Set("Origin", "http://127.0.0.1:9876")
	r.Header.Set("X-LCM-Caller", "Console")
	if code, _ := runCaller(r); code != http.StatusUnauthorized {
		t.Fatalf("browser without key with forged caller: want 401, got %d", code)
	}

	r = httptest.NewRequest(http.MethodPost, "/execute", strings.NewReader("{}"))
	r.Header.Set(keyHeader, "wrong")
	if code, authed := runCaller(r); code != 200 || authed {
		t.Fatalf("local non-browser wrong key (transition): code %d authed %t", code, authed)
	}

	t.Setenv("LCM_DO_REQUIRE_KEY", "1")
	r = httptest.NewRequest(http.MethodPost, "/execute", strings.NewReader("{}"))
	if code, _ := runCaller(r); code != http.StatusUnauthorized {
		t.Fatalf("LCM_DO_REQUIRE_KEY=1 without key: want 401, got %d", code)
	}

	r = httptest.NewRequest(http.MethodGet, "/status", nil)
	r.Header.Set("Origin", "http://evil.example")
	if code, _ := runCaller(r); code != 200 {
		t.Fatalf("GET must pass: %d", code)
	}
}

func TestInjectKeyScript(t *testing.T) {
	withKey(t, "abc123")
	out := injectKeyScript("<html><head><title>x</title></head><body></body></html>")
	if !strings.Contains(out, "<head><script>") && !strings.Contains(out, "<head>\n  <script>") {
		t.Fatalf("shim not directly after <head>: %s", out)
	}
	if !strings.Contains(out, "'abc123'") || !strings.Contains(out, keyHeader) {
		t.Fatalf("shim lacks key or header name")
	}
	daemonKey = ""
	if injectKeyScript("<head>") != "<head>" {
		t.Fatalf("no key must mean no shim")
	}
}

func TestStripCORS(t *testing.T) {
	rec := httptest.NewRecorder()
	rec.Header().Set("Access-Control-Allow-Origin", "*")
	stripCORS(rec)
	if rec.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatalf("CORS header still present")
	}
}

func TestElevationDecision(t *testing.T) {
	root := `D:\Git_Repositories`
	policy := map[string]string{"lcm_inventory/tools/mount-macriumlatestbaseline.ps1": "mount"}
	cases := []struct {
		cmd  string
		want bool
	}{
		{`& pwsh -File "D:\Git_Repositories\LCM_Inventory\tools\Mount-MacriumLatestBaseline.ps1" -Drive F:`, true},
		{`pwsh -File LCM_Inventory\tools\Mount-MacriumLatestBaseline.ps1`, true},
		{`pwsh -File D:\Git_Repositories\LCM_Inventory\tools\Invoke-MacriumDailyBcrBaseline.ps1 -ElevatedWorker`, false},
		{`whoami /groups`, false},
		{`pwsh -File C:\Elsewhere\LCM_Inventory\tools\Mount-MacriumLatestBaseline.ps1`, false},
	}
	for _, c := range cases {
		_, got := resolveElevatedAtom(c.cmd, root, policy)
		if got != c.want {
			t.Errorf("%s: want %t, got %t", c.cmd, c.want, got)
		}
	}
	if got := normalizeAtomPath(filepath.Join(root, "LCM_Inventory", "tools", "X.ps1"), root); got != "lcm_inventory/tools/x.ps1" {
		t.Errorf("normalize: %s", got)
	}
}

func TestBuildCommandLine(t *testing.T) {
	got := buildCommandLine(`C:\Program Files\PowerShell\7\pwsh.exe`, []string{"-Command", `Get-Date; "x y"`})
	if !strings.HasPrefix(got, `"C:\Program Files\PowerShell\7\pwsh.exe" -Command `) {
		t.Fatalf("command line: %s", got)
	}
}

func TestVerifyLegalElevationFastPath(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "LCM_Inventory", "data", "tools")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	pol := `{"elevated_atoms":[{"script":"LCM_Inventory/tools/Mount-MacriumLatestBaseline.ps1","tool_admin":3,"parameters":""},` +
		`{"script":"LCM_Inventory/tools/Worker.ps1","tool_admin":3,"parameters":"-ElevatedWorker"},` +
		`{"script":"LCM_Inventory/tools/Bad.ps1","tool_admin":1,"parameters":""}],"tools":{"LCM_Inventory\\tools\\Mount-MacriumLatestBaseline.ps1":3}}`
	if err := os.WriteFile(filepath.Join(dir, "elevation_policy.json"), []byte(pol), 0o644); err != nil {
		t.Fatal(err)
	}
	policyCache = nil
	mount := filepath.Join(root, "LCM_Inventory", "tools", "Mount-MacriumLatestBaseline.ps1")
	cases := []struct {
		name string
		req  elevationRequest
		want bool
		path string
	}{
		{"atom+auth", elevationRequest{Command: "pwsh -File " + mount, Authenticated: true}, true, "fast"},
		{"atom no auth", elevationRequest{Command: "pwsh -File " + mount}, false, "fast"},
		{"no atom", elevationRequest{Command: "whoami /groups", Authenticated: true}, false, "fast"},
		{"catalog error owner below level 3", elevationRequest{Command: "pwsh -File LCM_Inventory\\tools\\Bad.ps1", Authenticated: true}, false, "fast"},
		{"switch missing", elevationRequest{Command: "pwsh -File LCM_Inventory\\tools\\Worker.ps1", Authenticated: false}, false, "slow"},
		{"switch present", elevationRequest{Command: "pwsh -File LCM_Inventory\\tools\\Worker.ps1 -ElevatedWorker", Authenticated: true}, true, "fast"},
		{"elevated flag no atom", elevationRequest{Command: "whoami", AskedElevated: true}, false, "slow"},
	}
	for _, c := range cases {
		v := verifyLegalElevation(c.req, root)
		if v.Elevate != c.want || v.Path != c.path {
			t.Errorf("%s: got elevate=%t path=%s (%s)", c.name, v.Elevate, v.Path, v.Reason)
		}
	}
	policyCache = nil
}

// TestCallerDecision covers the CRP-343 call table (Specification T2) row by row.
func TestCallerDecision(t *testing.T) {
	list := map[string]bool{"lcm_inventory/tools/invoke-macriummountworker.ps1": true}
	worker := []string{"lcm_inventory/tools/invoke-macriummountworker.ps1"}
	registry := []string{"lcm_inventory/tools/set-lcmmachineregistry.ps1"}
	cases := []struct {
		name          string
		tool          string
		level         int
		allowed       map[string]bool
		atoms         []string
		switchMissing bool
		want          bool
	}{
		{"admin caller, legal atom", "t", adminFull, nil, worker, false, true},
		{"controlled caller, listed atom", "t", adminControlled, list, worker, false, true},
		{"controlled caller, unlisted atom", "t", adminControlled, list, registry, false, false},
		{"controlled caller, listed and unlisted", "t", adminControlled, list, append(append([]string{}, worker...), registry...), false, false},
		{"granted caller", "t", adminGranted, nil, worker, false, false},
		{"TBD caller", "t", adminTBD, nil, worker, false, false},
		{"no caller tool", "", adminFull, nil, worker, false, false},
		{"admin caller, no atom", "t", adminFull, nil, nil, false, false},
		{"admin caller, switch missing", "t", adminFull, nil, worker, true, false},
	}
	for _, c := range cases {
		got, why := callerDecision(c.tool, c.level, c.allowed, c.atoms, c.switchMissing)
		if got != c.want {
			t.Errorf("%s: want %t, got %t (%s)", c.name, c.want, got, why)
		}
	}
}

func TestIsCompositeCommand(t *testing.T) {
	cases := map[string]bool{
		`& pwsh -NoProfile -File 'D:\x\Set-LcmMachineRegistry.ps1' -KeyPath 'HKLM:\SOFTWARE\LCM' -Value 'a;b'`: false,
		`pwsh -File D:\x\Invoke-MacriumMountWorker.ps1 -CandidateDrives 'F;G;H;I'`:                             false,
		`& pwsh -File 'D:\x\Set-LcmMachineRegistry.ps1' -Help; whoami /groups`:                                 true,
		`pwsh -File D:\x\a.ps1 | Out-File x`:                                                                   true,
		`pwsh -File D:\x\a.ps1 && whoami`:                                                                      true,
		`pwsh -File D:\x\a.ps1 -Value "$(whoami)"`:                                                             true,
		`pwsh -File D:\x\a.ps1 > out.txt`:                                                                      true,
		"pwsh -File D:\\x\\a.ps1\nwhoami":                                                                      true,
	}
	for cmd, want := range cases {
		if got := isCompositeCommand(cmd); got != want {
			t.Errorf("%q: want %t, got %t", cmd, want, got)
		}
	}
}
