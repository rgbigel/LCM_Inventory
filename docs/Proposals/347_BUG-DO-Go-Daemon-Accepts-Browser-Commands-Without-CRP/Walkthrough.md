# Walkthrough: BUG-347 - DO Go Daemon Accepts Browser Commands Without CRP-309 Guard

## 1. Executive Summary
Implementation and verification records for BUG-347.

## 2. Verification Evidence
- 2026-11-17 14:17:55 (Claude, DOIT). Root cause: the Go port (`src/do`, 2026-11-11) maps `/execute`, `/api/execute`, `/action`, `/api/action` straight to `handleExecute`, which runs the raw command with the daemon token (task `\LCM_DesktopDaemon_rgbig`, RunLevel Highest) and parses any Content-Type as JSON; the CRP-309 gateway exists only in `tools/LcmDesktopDaemon.ps1` (not running). Pre-fix probe: `OPTIONS /execute` -> 405 (JSON cross-site blocked), preflight-free `text/plain` POST would reach the handler (inferred from code, not executed).
- `gofmt -l daemon.go guard.go guard_test.go`: clean; `go vet ./...`: exit 0; `go test -run TestGuardMutations`: PASS 13/13; `go build -o <scratchpad>`: exit 0 (no artifact in the repo). Pre-existing gofmt deviations in `client.go`, `main.go`, `types.go`, `winutil.go` left unchanged.
- Deployment: backup `LCM_Inventory/scratch/do-before-bug347.exe` (SHA-256 34851938D63BC24E); `POST /stop` (PID 11692 exited); `DoT/do.exe` = new build (SHA-256 0BDA19DAC3F97DB4); `Start-ScheduledTask LCM_DesktopDaemon_rgbig` -> PID 22384, Session 1, ONLINE. Rollback: `POST /stop`, copy the backup back, `Start-ScheduledTask LCM_DesktopDaemon_rgbig`.
- Live probes (`POST /execute`, harmless command writing a marker file into the Claude scratchpad): A no Origin + JSON -> 200, executed; B Origin `http://127.0.0.1:9876` + JSON -> 200, executed; C foreign Origin + text/plain -> 403, not executed; D foreign Origin + JSON -> 403, not executed; E Origin `null` + JSON -> 403, not executed; F no Origin + text/plain -> 415, not executed. `do.exe "echo DO_OK" -sync` -> DO_OK; `GET /status` ONLINE; `GET /hub` 200. Refusals are logged (`last_do.json` Status DENIED).
- Operator live test pending (Gate 2): Control Hub and Tool Explorer buttons (same-origin JSON) must still dispatch.
- Side observation (not changed): daemon-served pages also call `/set_priority`, `/query_all_short_names`, `/print`, `/abort`, which the Go mux does not register (they fall to `/`); a further gap of the Go port, to be registered separately.
