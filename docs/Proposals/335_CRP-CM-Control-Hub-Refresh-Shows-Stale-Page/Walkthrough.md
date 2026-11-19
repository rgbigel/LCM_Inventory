# Walkthrough: CRP-335 - CM Control Hub Refresh Shows Stale Page

Module: docs/Proposals/335_CRP-CM-Control-Hub-Refresh-Shows-Stale-Page/Walkthrough.md  
Purpose: Verification evidence for CRP-335 before Gate 2.  
Path: LCM_Inventory/docs/Proposals/335_CRP-CM-Control-Hub-Refresh-Shows-Stale-Page/Walkthrough.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4  
Status: Verified and deployed (Gate 2 pending)  
Date: 2026-11-15 16:55:37

---

| Check (2026-11-15) | Result |
|:---|:---|
| `gofmt -l daemon.go`, `go vet ./...`, `go build` | clean, exit 0, exit 0 |
| New build as a second daemon on port 9877 (live daemon on 9876 untouched) | `GET /displays/refresh/hub` -> 405 |
| `POST /displays/refresh/hub` | `state: Current` after 3.4 s; `CM_CONTROL_HUB.html` re-rendered (16:30:14 -> 16:48:39); revision changed; page contains BUG-336 (registered after the previous render); log `data/logs/lcm/displays/hub-20261115_164835-daemon.log` |
| `POST /displays/refresh/tool_intents` (no renderer) | `state: Current` (unchanged behaviour) |

Observations (not changed): `/hub-refresh` is a stub that only answers OK; `client.go`, `main.go`, `types.go`, `winutil.go` are not gofmt-formatted (pre-existing); the ShowCM run logs `Invoke-InteractiveDesktop` although RULE-ELEV-006 lists it as retired.

Gate 2: redeploy the daemon (Implementation Plan section 3), then press Refresh in the hub after any ledger change.

## Deployment (2026-11-15 16:54, operator-authorized)

- Backup of the previous binary: `LCM_Inventory/scratch/do-before-crp335.exe` (SHA-256 prefix AFE6962069526AC7). Rollback: stop via `POST /stop`, copy it back to `LCM_Inventory/DoT/do.exe`, `Start-ScheduledTask LCM_DesktopDaemon_rgbig`.
- Sequence: `POST /stop` (pid 7848 exited) -> `DoT/do.exe` replaced by the CRP-335 build -> `Start-ScheduledTask LCM_DesktopDaemon_rgbig` (RunLevel Highest) -> new pid 14812.
- Live checks: `/status` ONLINE; `GET /displays/refresh/hub` 405; `POST /displays/refresh/hub` `state: Current` and `CM_CONTROL_HUB.html` re-rendered; `do.exe "echo DO_OK" -sync` round trip OK.
- Observation (code not changed by this CRP): a normal `do.exe` dispatch without `-elevated` already runs at High Mandatory Level, because the daemon runs elevated. This is the self-elevation path the operator named (2026-11-15); a separate CRP if it is to be closed.
