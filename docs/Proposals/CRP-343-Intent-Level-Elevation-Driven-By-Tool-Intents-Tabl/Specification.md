# Specification: CRP-343

Module: docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification.md  
Purpose: Intent-Level Elevation Driven By Tool Intents Table  
Path: LCM_Inventory/docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-17 13:40:12

```yaml
CRP-ID: CRP-343
Title: Intent-Level Elevation Driven By Tool Intents Table
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-17 13:40:12
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 7
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-17: elevation is checked and enforced per atom/intent (tool_intents.elevated), not per tool (tools.admin). First of four CRPs; prerequisite for the other three.

## 2. Gate 0 Contract
### Target State
Two fields with distinct semantics (operator correction 2026-11-17, Section "Absorbed Operator Remarks"):
- `tools.admin` (tool level) = access restriction: the tool may be run by admin users only. It does not mean "runs elevated".
- `tool_intents.elevated` (atom level) = runtime elevation: exactly the atoms flagged `elevated` run elevated; every other atom of the same tool runs non-elevated.
- Example BCR: the BCR tool is admin-restricted; its atom "launch a BCR task" (Beyond Compare) is not elevated; the Macrium mount/unmount atoms it uses are elevated.
- Dispatch (DO gateway, `do.exe -elevated` routing) elevates per atom from `tool_intents.elevated`; access is checked per tool from `tools.admin`.
- RULE-ELEV-001 / RULE-ELEV-003 / RULE-ELEV-006 / RULE-ELEV-007 state both levels.
- Context (2026-11-17): `tool_intents` has 649 rows with an `elevated` column; `tools` has 320 rows, 85 with `admin = 1`; RULE-ELEV-006 routes on `tools.admin` today. Current data already conflicts with the consistency invariant: `Invoke-MacriumBcrReview.ps1` has `admin = 0` but uses the elevated mount/unmount atoms (`Mount-MacriumLatestBaseline.ps1` / `Dismount-MacriumCurrentBaseline.ps1`, `admin = 1`).

### Invariants and Exit Criteria
- Consistency invariant: an `elevated` atom may only be called from a tool with `admin = 1`; any elevated atom reachable from a non-admin tool is a governance error (no meaning in the LCM security context) and fails the consistency check.
- No privileged command (RULE-ELEV-003 list) runs without an `elevated` atom that declares it; `Assert-RepoElevationConsistency` checks both levels (atom elevation, tool admin restriction).
- Non-interactive runners are never blocked by UAC (RULE-ELEV-002); elevated consoles keep `-NoExit` (RULE-ELEV-005).
- Exit: catalog query lists every elevated atom with its owning tool and that tool's `admin` value, with zero consistency violations; a tool with mixed atoms runs its non-elevated steps unelevated (logged); rules and adapters synced (RULE-AUTH-002).

### Explicit Non-Goals
- Changing BCR, Beyond Compare or AHK behaviour (CRP-344, CRP-345, CRP-346).
- Re-classifying all 85 admin tools in one pass; only the mechanism plus the Macrium mount/unmount atoms as first cases.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

## 4. Corollary Scope (operator, 2026-11-17)

1. **Consistency-check atom**: one atom verifies (a) every `tool_intents.elevated = 1` atom is owned by and called only from tools with `tools.admin = 1`; (b) every privileged command (RULE-ELEV-003 list) inside a tool sits in an `elevated` atom. Violations fail the check; it runs in the readiness gates and at good morning.
2. **Temporary cleanup tool**: one-off tool that reports the current violations (first known case: `Invoke-MacriumBcrReview.ps1` `admin = 0` calling the `admin = 1` mount/unmount tools) and applies the operator-accepted corrections to `tools.db` (structural DB changes only after CRP acceptance, WORKPLAN D-22); retired after the clean state is reached.
3. **Atoms inside tools**: elevated steps are cut out of tools into separately dispatched atoms (registered intents), so a tool's non-elevated steps never run elevated.
4. **DO front-end / back-end elevation flow**: operator review of which component checks elevation and by which method (current state: section 5); target: decided in this CRP before implementation.

## 5. Current DO Elevation Flow (analysis 2026-11-17, read-only)

| Step | Component | What it does about elevation | Evidence |
|:---|:---|:---|:---|
| 1 | Caller (PowerShell tool, AI, Control Hub page) | Decides itself whether to ask for elevation (`-elevated` flag or `options.elevated`); no catalog lookup in code: no tool or module queries `tools.admin` or `tool_intents.elevated` (RULE-ELEV-006 is an AI behaviour rule only). | grep `tools/`, `modules/`: no match |
| 2 | DO front end `do.exe` (client) | Turns `-elevated` into `"elevated": true` in the JSON body; no check of any kind. | `src/do/client.go:51-98` |
| 3 | DO back end `do.exe daemon` on 127.0.0.1:9876 | `/execute` accepts any command string; no caller identity, no catalog lookup, no admin or intent check. The `elevated` flag is only logged and, in the async path, skips the direct-exe shortcut; it never changes the token. Every child inherits the daemon token. | `src/do/daemon.go:193-422` |
| 4 | Daemon start | Scheduled task `\LCM_DesktopDaemon_rgbig`, RunLevel **Highest**, running (PID 11692 since 08:50). So everything dispatched through DO runs elevated, with or without `-elevated`; this is why Beyond Compare shows `Administrator:`. A second task `\LCM_Daemon_InteractiveStarter` (RunLevel Limited, state Ready) has a malformed action path (`\ ...do.exe daemon\`). | `Get-ScheduledTask` |
| 5 | Exposure | Responses of display/API routes carry `Access-Control-Allow-Origin: *`. For `/execute` a browser preflight is refused (`OPTIONS` -> HTTP 405, no CORS headers; verified 2026-11-17), so JSON-typed cross-site POSTs are blocked. But `handleExecute` parses the body as JSON regardless of `Content-Type` and checks no `Origin`, so a preflight-free `text/plain` POST from any local browser page would still reach the elevated `/execute` [INFERRED from code; not tested because it would execute a command]. | `src/do/daemon.go:193-231`, `:741-744`; `OPTIONS` probe |

Consequence for the target state (corrected by the operator 2026-11-17): the only place that can enforce `tools.admin` / `tool_intents.elevated` is the back end, because the front end and the callers are not trustworthy. The daemon stays elevated (it cannot run non-elevated); it launches atoms with `elevated = 0` with a non-elevated token and atoms with `elevated = 1` elevated. Requests name an intent key, not a raw command. Neither launch mode may limit the operator's access: every launched task that needs operator responses runs visibly on the interactive Session 1 desktop.

Candidate methods for the non-elevated launch (design choice of this CRP, not decided): (a) the daemon duplicates the token of the operator's shell (`explorer.exe`, same session) and starts the atom with `CreateProcessWithTokenW` (medium integrity, same desktop); (b) a non-elevated launcher task (RunLevel Limited, interactive), e.g. the repaired `\LCM_Daemon_InteractiveStarter`; (c) the linked (filtered) token of the daemon's own elevated token. Side effect to respect: windows of elevated processes cannot be driven by non-elevated AHK atoms (UIPI), which is one more reason for CRP-344.
## 6. Caller Authentication (amendment, operator 2026-11-17)

The CRP-309 token gateway is not an adequate model and must not be ported as is (analysis 2026-11-17, BUG-347):
- Tier 2 (the default tier) is authorized without any token (`LcmSecurityGateway.ps1:90-92`).
- Tier 3 without a token is authorized when the request declares `caller` as `Console`, `CLI`, `WebUI` or `AntigravityAgent`; the caller writes this field itself (`LcmSecurityGateway.ps1:105-113`).
- `POST /api/token` issues a token to anyone who asks (`LcmDesktopDaemon.ps1:558-563`).
- The Go daemon (`src/do`) implements none of it; BUG-347 (2026-11-17) adds only the baseline guard: foreign browser origins and non-JSON bodies are refused.

Target state additions:
1. The back end authenticates the caller, not the request content: a caller proves itself with a secret a web page cannot obtain (for example a per-boot key readable only by the operator account and the daemon), never with a self-declared `caller` field.
2. Token issuance (if tokens stay) requires that same authentication; an unauthenticated `/token` request is refused.
3. Authorization uses the authenticated caller plus the two catalog fields: `tools.admin` (may this caller run the tool) and `tool_intents.elevated` (does this atom run elevated).
4. The BUG-347 guard stays in place as the first layer.
5. Exit criterion addition: an unauthenticated request with a forged `caller` and no secret is refused for every non-read route; refusals are logged with the claimed caller.
## Absorbed Operator Remarks

> Actually, i think the problem to decide all this can be fully relaxed as follows:
> -  while elevation of BCR is needed to free or allocate the (F:) baseline, it is not necessary (and even a bad choice) to run BC elevated. There is more to this problem on a second level: i want elevation checked and enforced on the "atomar" level, not on tool level. That distinction is in the tool intents table. My design had the atoms (in this example, mount/unmount of Reflect backups are the atoms, individual AHK tasks would be another example). Once BC is not elevated, the problem areas collapse.
> - getting the tab names via AHK should be simple. Note my intent here: the AHK tool is usually not elevated, but needs to distinguish the "AHK atoms" as individual intents. Not every AHK action is allowed, only those which have an atom, and they may or may not need elevation.
>
> Resolution: several CRPs,
> - first make the distinction on the atomar level, using the intents table to drive elevation.
> - make BCR non elevated (intents table)
> - form atoms for AHK (only use at this case is within BCR, i think), disallow AHK use for undefined intents.
> - codify the BCR distinction of windows started for BCR, and locating/activating the tab to refresh (instead of launching a new window)

(Operator, 2026-11-17; shared source of CRP-343, CRP-344, CRP-345, CRP-346.)

> Modify 343. There is a distinction between the semantics of admin in the tools table vs. the intents table. the former means, this tools will be restricted to admin users. the intents table refines that on the atomar level: whereas BCR is elevated, the atom "launch a bcr task" is not, but the other atoms used in BCR may be elevated again. Obviously, any elevated atom in intents  that is called from a tool that is not admin makes no sense in our security context. So, the tools table has a field "admin", and the intents table has the field "elevated".

(Operator, 2026-11-17; correction of the CRP-343 target state.)

> corrolary: we need an atom that checks this. a (temporary) tools will be required to run to clean the current state, we must form atoms within tools that determine elevation. I need to review the flow in the security of do-backend and do-frontend, which one is going to check the elevation and by which methods.

(Operator, 2026-11-17; corollary to the CRP-343 target state.)

> i do NOT think the daemen can be "run non-elevated". but it can run unelevated tasks unelevated if we need to make this distinction. Both cases should not limit accessibility for a user to reach tasks the daemon launches, when they require opertator responses

(Operator, 2026-11-17; correction of section 5.)

> i will do refresh on BCR tabs myself until we have this sortedout, no problem.
> your remark "I didn't port the CRP-309 tokens. They wouldn't stop a web page: most actions need no token, the admin tier accepts a caller name the page writes itself, and /api/token gives a token to anyone. Real caller authentication belongs to CRP-343."
> required that 343 is amended accordingly.
> What will happen now when i refresh an existing ShowXXX window? will it fail?
> more questions to the AHK crp:
> - is it mentioned in the list of external tools? we must check that all tools we used are documented.

(Operator, 2026-11-17; amends CRP-343 section 6 and CRP-345 section 4.)