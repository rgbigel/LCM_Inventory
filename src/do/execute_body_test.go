/*
================================================================================
FILE NAME      : execute_body_test.go
PACKAGE        : main
DESCRIPTION    : Tests of parseExecuteBody: ExecuteRequest and ControlHub ActionRequest bodies (BUG-380 B13).
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-20
LAST MODIFIED  : 2026-11-20
VERSION        : 10.2.9
GO VERSION     : 1.22+
ENCODING       : ASCII (No BOM)
================================================================================
CHANGE LOG:
2026-11-20 - 10.2.9: BUG-380 B13 initial tests.
================================================================================
*/

package main

import "testing"

func TestParseExecuteBodyHonoursActionOptions(t *testing.T) {
	body := []byte(`{"action":"DO","target":"x","command":"pwsh -File a.ps1","options":{"sync":true,"timeoutMs":590000},"caller":"ControlHub"}`)
	req, err := parseExecuteBody(body)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if req.Command != "pwsh -File a.ps1" {
		t.Fatalf("command = %q", req.Command)
	}
	if !req.Sync {
		t.Fatalf("options.sync was dropped (the BUG-380 B13 defect)")
	}
	if req.TimeoutMs != 590000 {
		t.Fatalf("timeoutMs = %d", req.TimeoutMs)
	}
}

func TestParseExecuteBodyKeepsPlainExecuteRequest(t *testing.T) {
	req, err := parseExecuteBody([]byte(`{"command":"whoami","sync":true,"elevated":false,"windowStyle":"Hidden"}`))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !req.Sync || req.WindowStyle != "Hidden" || req.Elevated {
		t.Fatalf("plain request changed: %+v", req)
	}
}

func TestParseExecuteBodyAsyncStaysAsync(t *testing.T) {
	req, err := parseExecuteBody([]byte(`{"action":"DO","command":"notepad.exe","options":{"sync":false,"windowStyle":"Hidden"}}`))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if req.Sync || req.WindowStyle != "Hidden" {
		t.Fatalf("async request changed: %+v", req)
	}
}

func TestParseExecuteBodyRejectsMissingCommand(t *testing.T) {
	if _, err := parseExecuteBody([]byte(`{"action":"DO","options":{"sync":true}}`)); err == nil {
		t.Fatalf("expected an error for a body without command")
	}
	if _, err := parseExecuteBody([]byte(`not json`)); err == nil {
		t.Fatalf("expected an error for a non-JSON body")
	}
}
