# Implementation Plan: BUG-347 - DO Go Daemon Accepts Browser Commands Without CRP-309 Guard

## 1. Executive Summary & Problem Context
Security regression of the Go port (src/do, 2026-11-11): the running elevated daemon (do.exe daemon, task LCM_DesktopDaemon_rgbig, RunLevel Highest) executes any POST to /execute, /api/execute, /action, /api/action without caller check; the CRP-309 PowerShell gateway (LcmTokenVault, LcmSecurityGateway) was not ported. handleExecute parses any Content-Type as JSON and checks no Origin, so a preflight-free cross-site POST from a local browser page can run commands as Administrator. Operator 2026-11-17: top priority.

## 2. Gate 0 Traceability
- Map each implementation component and verification activity to the accepted Gate 0 target-state clause.

## 3. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for DO Go Daemon Accepts Browser Commands Without CRP-309 Guard.

## 4. Verification Plan
- Automated Pester tests and readiness quality gates.

## 5. Implemented Changes (Claude, 2026-11-17, DOIT)
- `src/do/guard.go` (new, 10.2.3): `guardMutations` wraps the mux; `checkMutationRequest` (Origin allow-list for the daemon port, `Sec-Fetch-Site: cross-site` refusal, JSON-only bodies); `denyLogger` (default `recordActionLog`, replaced in tests).
- `src/do/guard_test.go` (new): 13 table cases (allowed local tool / own page / localhost / body-less stop; refused foreign text/plain, foreign body-less, `null`, other local port, cross-site marker, form post, text/plain; GET and OPTIONS pass).
- `src/do/daemon.go` (10.2.2 -> 10.2.3): `daemonPort = port` in `RunDaemon`; `Handler: guardMutations(daemonMux)`; header and change log.
- Deployment: `DoT/do.exe` replaced (CRP-335 procedure); rollback copy `LCM_Inventory/scratch/do-before-bug347.exe`.