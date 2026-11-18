# Specification: BUG-347

Module: docs/Proposals/347_BUG-DO-Go-Daemon-Accepts-Browser-Commands-Without-CRP/Specification.md  
Purpose: DO Go Daemon Accepts Browser Commands Without CRP-309 Guard  
Path: LCM_Inventory/docs/Proposals/347_BUG-DO-Go-Daemon-Accepts-Browser-Commands-Without-CRP/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: In Progress  
Date: 2026-11-17 14:14:06

```yaml
CRP-ID: BUG-347
Title: DO Go Daemon Accepts Browser Commands Without CRP-309 Guard
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 14:14:06
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 10
App-ID: None
```

---

## 1. Executive Summary & Intent
Security regression of the Go port (src/do, 2026-11-11): the running elevated daemon (do.exe daemon, task LCM_DesktopDaemon_rgbig, RunLevel Highest) executes any POST to /execute, /api/execute, /action, /api/action without caller check; the CRP-309 PowerShell gateway (LcmTokenVault, LcmSecurityGateway) was not ported. handleExecute parses any Content-Type as JSON and checks no Origin, so a preflight-free cross-site POST from a local browser page can run commands as Administrator. Operator 2026-11-17: top priority.

## 2. Gate 0 Contract
BUG: target inherent in the defect (RULE-GOAL-002); DOIT to Gate 2; operator priority: top.

### Target State
- No web page other than the daemon's own (`http://127.0.0.1:9876`, `http://localhost:9876`) can make the daemon execute anything: every non-GET/HEAD/OPTIONS request with a foreign or `null` `Origin`, or `Sec-Fetch-Site: cross-site`, is refused (HTTP 403); every request body must be `application/json` (else HTTP 415); refusals are logged.
- Local callers (`do.exe`, PowerShell tools: no `Origin`, JSON) and the daemon-served pages (Control Hub, Tool Explorer, Inventory Viewer: same origin, JSON) keep working.

### Invariants and Exit Criteria
- One guard in front of the whole mux (`guardMutations`, `src/do/guard.go`), so routes added later are covered; route handlers unchanged.
- Exit: `gofmt`, `go vet`, `go build` clean; guard unit tests pass; live probes against the redeployed daemon show A/B executed, C-F refused and not executed; operator live test of Control Hub actions at Gate 2.

### Explicit Non-Goals
- Porting the CRP-309 token vault 1:1: it would not stop browser pages (tier 2 needs no token; tier 3 is granted to a self-declared `caller` of `Console`/`CLI`/`WebUI`/`AntigravityAgent`; `/api/token` issues to anyone). Real caller authentication and intent-key requests belong to CRP-343.
- Local non-elevated processes reaching the elevated daemon (by design of DO; CRP-343 decides).
- `Access-Control-Allow-Origin: *` on read-only display routes (information exposure of displays to foreign pages; follow-up).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.
