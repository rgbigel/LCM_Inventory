/*
================================================================================
FILE NAME      : route_test.go
PACKAGE        : main
DESCRIPTION    : Unit tests of the CRP-361 route decision (one case per T2 table row).
AUTHOR         : Rolf, Claude
DATE CREATED   : 2026-11-19
LAST MODIFIED  : 2026-11-19
VERSION        : 10.2.8
GO VERSION     : 1.22+
ENCODING       : UTF-8 (No BOM)
================================================================================
CHANGE LOG:
2026-11-19 - 10.2.8: CRP-361 segment 1.
================================================================================
*/

package main

import "testing"

func TestRouteDecision(t *testing.T) {
	cases := []struct {
		name string
		in   routeInput
		want string
	}{
		{"T2 row 1: same rights, terminal (sync)", routeInput{HasDesktop: true}, routeLocal},
		{"T2 row 1: same rights, own desktop (window)", routeInput{HasDesktop: true, NeedsWindow: true}, routeLocal},
		{"T2 row 1: no desktop but no window needed (sync)", routeInput{HasDesktop: false}, routeLocal},
		{"T2 row 2: request from a browser page", routeInput{FromBrowser: true, HasDesktop: true}, routeDaemon},
		{"T2 row 3: elevated atom", routeInput{ElevatedAtoms: []string{"lcm_inventory/tools/x.ps1"}, HasDesktop: true}, routeDaemon},
		{"T2 row 3: -elevated without atom", routeInput{AskedElevated: true, HasDesktop: true}, routeDaemon},
		{"T2 row 4: elevated caller starts non-elevated work", routeInput{CallerElevated: true, HasDesktop: true}, routeDaemon},
		{"T2 row 5: caller without desktop needs a window", routeInput{NeedsWindow: true, HasDesktop: false}, routeDaemon},
		{"-daemon forces the daemon", routeInput{ForceDaemon: true, HasDesktop: true}, routeDaemon},
	}
	for _, c := range cases {
		got, reason := routeDecision(c.in)
		if got != c.want {
			t.Errorf("%s: got %s (%s), want %s", c.name, got, reason, c.want)
		}
		if reason == "" {
			t.Errorf("%s: empty reason", c.name)
		}
	}
}

// T3: the local path is never chosen when elevation is involved in any form.
func TestLocalNeverElevates(t *testing.T) {
	for _, in := range []routeInput{
		{AskedElevated: true, HasDesktop: true},
		{ElevatedAtoms: []string{"a.ps1"}, HasDesktop: true},
		{CallerElevated: true, HasDesktop: true},
	} {
		if got, _ := routeDecision(in); got == routeLocal {
			t.Errorf("local path chosen for %+v", in)
		}
	}
}
