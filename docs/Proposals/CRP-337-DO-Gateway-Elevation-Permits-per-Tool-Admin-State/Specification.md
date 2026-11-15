# Specification: CRP-337

Module: docs/Proposals/CRP-337-DO-Gateway-Elevation-Permits-per-Tool-Admin-State/Specification.md  
Purpose: Align the DO gateway with the operator's elevation model: elevated execution only for tools whose atomic admin state requires it, and only for users in the Administrators group.  
Path: LCM_Inventory/docs/Proposals/CRP-337-DO-Gateway-Elevation-Permits-per-Tool-Admin-State/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Suggested (registered)  
Date: 2026-11-15 17:47:30

```yaml
CRP-ID: CRP-337
Title: DO Gateway Elevation Permits per Tool Admin State
Scope: LCM_Inventory
Target Scope: LCM_Inventory/src/do (daemon and client), daemon scheduled task, RULE-ELEV-006 documentation
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_Inventory]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-15 17:47:30
Status: Suggested
Plan-State: suggested
Progress-State: suggested
Priority: 7
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude on operator instruction (2026-11-15): "If this is not the way things work now, make a CRP, but do not change the code here." No code was changed. Structural and security-relevant: needs a Gate 0 discussion before implementation (RULE-GOAL-002).

## 1. Operator Model (2026-11-15)

- Elevation permits are controlled by the admin state of the atomic tool in the tools table (`tools.admin` in `LCM_Inventory/data/tools/tools.db`).
- Elevated execution is available only to users in the Administrators group (SID `S-1-5-32-544`).
- An earlier, inconclusive discussion considered two ports to separate permitted elevated from non-elevated dispatch.

## 2. Observed Implementation (2026-11-15, read-only)

- One port: 9876 (`GetDaemonPort`, overridable by `LCM_DAEMON_PORT`); no second port exists in code, configuration or docs.
- The daemon runs as scheduled task `LCM_DesktopDaemon_rgbig` with RunLevel Highest. Every dispatched command inherits that token: `do.exe "whoami /groups" -sync` without `-elevated` reports `High Mandatory Level`, the same as with `-elevated`.
- `-elevated` is carried in the request and logged (`client.go`, `daemon.go`), and changes only the launch path for `.exe` commands (`executeAsynchronous`); it does not grant or restrict privileges.
- The daemon does not look up `tools.admin` and does not check the caller's group membership.
- Consequence: any local un-elevated caller (including AI hosts) obtains elevated execution through DO, independent of the tool's admin state: a self-elevation path outside the defined security gates.

## 3. Gate 0 Contract (draft, for discussion)

- **Target State**: A command runs elevated only if (a) the resolved atomic tool has `tools.admin = 1` and (b) the requesting user is in `S-1-5-32-544`; all other commands run with a standard (filtered) token, whether or not `-elevated` is given. Denials are logged and reported to the caller.
- **Exit Criteria**: `whoami /groups` via DO without an admin tool shows Medium integrity; an admin tool by a member of Administrators runs High; the same tool by a non-member is refused with a logged reason; existing admin workflows (RULE-ELEV-006 routing) keep working.
- **Explicit Non-Goals**: no change to the tools table schema; no new elevation mechanism outside DO; no change to ADMINMODE (RULE-REV-011) semantics.

## 4. Design Questions for the Operator

1. One elevated daemon that launches standard-token children (token filtering), or two daemons/ports (standard and elevated)?
2. How a free-form command (not a catalog tool) is classified: always standard, or refused when `-elevated` is requested?
3. Where the group check happens: in the daemon (caller identity over loopback is not authenticated) or by a separate elevated broker.

## 5. Additional Evidence (2026-11-15, from Claude's Book 2 reading)

- `LCM_Inventory/docs/Implementation of Security in LCM.md` (10.2.0, 2026-11-09) already specifies the target model: a security gateway in the daemon runs a tool elevated only if the catalog marks it admin, otherwise un-elevated; GUIs (Beyond Compare, editors, browsers) must never run elevated (anti-GUI-poisoning invariant); elevation is confined to the atomic operation. This was realized in the PowerShell daemon (`tools/LcmDesktopDaemon.ps1`), not in the Go `do` daemon now serving port 9876.
- Consequence today: anything the Go daemon launches, including GUIs, runs at High integrity, which violates the anti-GUI-poisoning invariant.
- Two elevation flags exist: `tools.admin` and `tool_intents.elevated` in `tools.db` (observed); the target design must name one authority.
- Related lost capability of the same migration: `/hub-events` (completion push to open hubs) exists only in the PowerShell daemon.
