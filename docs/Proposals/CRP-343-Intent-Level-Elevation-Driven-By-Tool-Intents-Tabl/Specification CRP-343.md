# Specification: CRP-343

Module: docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification CRP-343.md  
Purpose: Intent-Level Elevation Driven By Tool Intents Table  
Path: LCM_Inventory/docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification CRP-343.md  
Authors: Rolf, Claude  
Version: 10.6.4
Status: Suggested  
Date: 2026-11-18 18:19:05

```yaml
CRP-ID: CRP-343
Title: Intent-Level Elevation Driven By Tool Intents Table
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-18 18:19:05
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
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
- Status (2026-11-17 19:48:36): refined by section 9 (tri-state tool privilege); the text below is the previous version.
- Consistency invariant (confirmed by the operator 2026-11-17, option A, see Absorbed Operator Remarks): an `elevated` atom must belong to a tool with `admin = 1`, and its **direct caller** must be a tool with `admin = 1`. A non-admin tool may call an admin tool; it reaches elevated atoms only through an admin tool. Example: `Invoke-MacriumDailyBcrBaseline.ps1` (admin 0) -> `Mount-MacriumLatestBaseline.ps1` (admin 1) -> elevated mount-worker atom. `tools.admin` is the tool property "admin", not the user's Administrators membership; the BCR tools stay `admin = 0`. No user-group check now; hiding admin tools from non-administrators is later polish.
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

1. **Consistency-check atom**: one atom verifies (a) every `tool_intents.elevated = 1` atom is owned by a tool with `tools.admin = 1` and is invoked directly only by tools with `tools.admin = 1` (real invocations only: `&`, `-File`, `do.exe`, `Start-Process`; a mere mention is not a call); (b) every privileged command (RULE-ELEV-003 list) inside a tool sits in an `elevated` atom. Violations fail the check; it runs in the readiness gates and at good morning.
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
## 7. Design Decisions (operator, 2026-11-17, chain A DOIT)

- Governing specification: `LCM_Inventory/docs/Implementation of Security in LCM.md` (10.2.0): atomic elevation, anti-GUI-poisoning invariant, security gateway in the daemon, namespace gate, transparent UAC fallback. CRP-343 implements it in the Go daemon (`src/do`), with `tool_intents.elevated` as the atom-level authority and `tools.admin` as the tool-level access restriction.
- D1 Non-elevated launch: the daemon duplicates the token of the operator's `explorer.exe` (same session) and starts `elevated = 0` atoms with `CreateProcessWithTokenW` (medium integrity, Session 1 desktop); fallback: the linked (filtered) token.
- D3 Dispatch during the transition: every command runs non-elevated unless it resolves to a registered intent with `elevated = 1` whose owning tool has `admin = 1` and the caller is authenticated; `-elevated` alone grants nothing; refusals are logged.
- D2 Caller authentication (operator option A): the security specification's "token credentials" are a per-boot key in `%LOCALAPPDATA%\LCM\do.key`; `do.exe` and governed tools send it as `X-LCM-Key`; the daemon injects it into the pages it serves (no `Access-Control-Allow-Origin` on those); browser requests without it are refused; `do.exe` sends it only to a listener that is the same `do.exe` binary (port-squatting guard). Transition: non-browser callers without the key are accepted but never elevated until migrated (`LCM_DO_REQUIRE_KEY=1` ends the transition).
- D4 Verify-legal-elevation helper in the back end (operator 2026-11-17): fast path = intent table only; slow path only when the fast path is inconclusive.
  - Conclusive (fast path): no registered atom named -> non-elevated; atom with `elevated = 0` -> non-elevated; atom with `elevated = 1`, owning tool `admin = 1`, caller authenticated -> elevated; unauthenticated request for an elevated atom -> non-elevated.
  - Inconclusive (slow path): one command naming atoms with conflicting flags; an intent narrowed by `parameters` whose switch is absent or ambiguous; `-elevated` requested for a command with no atom.
  - An atom with `elevated = 1` whose owning tool has `admin = 0` is a catalog error: never elevated, reported by the consistency check (not a slow-path case).
  - Slow path: identify the calling process (loopback TCP table -> PID -> image and command line) and from it the direct caller tool; elevate only when that tool has `admin = 1`; result allow/deny with the failed rule named in the log.
  - Read-only dry-run route `GET /api/elevation/verify?command=...` returns the same decision without executing.

## 8. Deferred: Integrity of the Intent Table (operator 2026-11-17, "later")

- Exposure: the elevation decision trusts `tool_intents.elevated` and `tools.admin` (`data/tools/tools.db`) and the generated `data/tools/elevation_policy.json`. Both are writable by the operator account, so any local process of that account could grant itself elevation by adding or flipping a row. Until protected, the key (D2) and the fast/slow path (D4) limit who may ask, not what is registered.
- Candidate measures (to decide later): write access to `tools.db` and the policy limited to Administrators (ACL), changes only through a governed elevated atom; the daemon generates or verifies the policy itself (hash/signature recorded at catalog update) and refuses a policy that does not verify; every change to an `elevated` or `admin` value is logged and appears in BCR / Gate 2.
- Not part of the current CRP-343 implementation segment.

## 9. Revised Contract: Tri-State Tool Privilege (operator 2026-11-17, option A)

Refines the consistency invariant of section 2 and D3/D4 of section 7.

### 9.1 Levels of `tools.admin`

Stored as integer (internal coding); Show* pages display the text.

| Code | Text | Runs at | May call elevated atoms |
|:---|:---|:---|:---|
| 1 | `none` | Medium | never |
| 2 | `controlled` | Medium | only through the DO (port 9876), and only the atoms in its declared atom list |
| 3 | `admin` | High, when dispatched as an elevated intent | other `admin` atoms directly (child inherits High) |

- `tool_intents.elevated` stays the atom-level authority: an `elevated = 1` intent must belong to a tool with code 3.
- Declared atom list: every `controlled` tool lists the elevated atoms it may call (catalog entry, projected into `tools.db`; script header `ADMIN DEPENDENCIES` per RULE-ELEV-007). These entries are the first "calls directly" edges of the tool-call xref table. Schema detail goes into the data design document during implementation.
- Comparisons use the ascending order: "may reach elevated atoms" = code >= 2.

### 9.2 Elevation borders (operator confirmed 2026-11-17)

| Caller -> callee | Allowed path |
|:---|:---|
| Medium -> Medium | direct |
| High -> High | direct, only when the caller is an `admin` (3) tool |
| Medium -> High | only through the DO (port 9876) or a visible operator UAC prompt |
| High -> Medium | only through the DO (non-elevated launch with the explorer token); never as a direct child, which would inherit High |

- The only gates to High are port 9876 and a visible operator UAC prompt.
- UIPI: a Medium process cannot drive an elevated window; AHK atoms exist in both variants, or one atom is elevated only for the parameter set that needs it (intent `parameters`).

### 9.3 Migration and first cases

- Data: `admin` 0 -> 1, 1 -> 3; then the reclassifications below. Catalog JSON (transition fallback) carries the same integer.
- `Invoke-MacriumBcrReview.ps1`, `Invoke-MacriumDailyBcrBaseline.ps1`, `Mount-MacriumLatestBaseline.ps1` -> 2 (`controlled`), atom lists: mount worker `Invoke-MacriumMountWorker.ps1`, `Set-LcmMachineRegistry.ps1`, `Dismount-MacriumCurrentBaseline.ps1` as each tool actually calls them.
- Consequences: the BCR baseline tool dispatches the mount worker and the registry atom through the DO itself; the `Mount-MacriumLatestBaseline.ps1 -ImagePath` hop stays only as the operator's manual mount entry if it is not a duplicate; the legacy `-ElevatedWorker` entry of `Invoke-MacriumDailyBcrBaseline.ps1` is removed; further legacy duplicates found on the way are removed and listed (operator 2026-11-17, "carefully kill legacy").
- Rules: RULE-ELEV-001 / 003 / 006 / 007 state the three levels and the border table (RULE-AUTH-002 sync).

### 9.4 Point O-1 (decided: B, operator 2026-11-17)

- Decision B: D4 stays as decided; the fast path checks the atom only; the caller rule is enforced by the consistency check (static) and on the slow path. Candidate A below is not implemented.

- D4 fast path checks only the atom; the caller rule is enforced statically (consistency check) and at runtime only on the slow path. Candidate: run the caller check (direct caller tool code >= 2 and atom in its list) on every request that would elevate; elevated requests are rare (mount, registry, dismount), so the cost is small.

### 9.5 Exit criteria additions

- Consistency check with the three levels: zero violations.
- Show* pages display `none` / `controlled` / `admin`.
- Diagrams: call chains and the elevation decision in `LCM_Inventory/docs/Implementation.md`; use cases in `docs/Requirements.md` (operator 2026-11-17).

### 9.6 Delivery: data and border enforcement in one segment (operator 2026-11-18)

- The integer migration of `tools.admin` and the enforcement at every elevation border ship in the same segment and are deployed together; there is no intermediate state with tri-state data and boolean code.
- Reason (verified 2026-11-18): the readers compare against the binary coding. `src/do/elevation.go:112` (`ToolAdmin != 1` = catalog error) and `:121` (`admin == 1`), `tools/Export-LcmElevationPolicy.py:78/83` (`admin != 1`, `admin == 1`), the Tool Explorer (`assets/lcm-tool-explorer.js`, `t.Admin` truthiness and `true`/`false` values in badge, run, filter, editor). With migrated data alone, every `none` tool (1) would read as admin and every `admin` tool (3) as a catalog error.
- Border points enforced in this segment (section 9.2 table):
  - DO back end (`src/do/elevation.go`, `callerid.go`): an elevated atom is granted only when its owning tool has code 3 and the direct caller is code 3, or code 2 with the atom in its declared list; every other request runs Medium. High -> Medium launches keep the explorer token (D1).
  - Policy export and consistency check (`Export-LcmElevationPolicy.py`): the three levels, the declared atom lists, and the violation kinds for a code-2 tool calling an atom not in its list or calling it directly instead of through the DO.
  - AHK border (`modules/LcmAhkAtoms.psm1`): the elevation-match check stays; an elevated AHK atom is reached only through the DO.
  - Catalog writers (`tools/Update-ToolCatalog.ps1`, `Sync-LcmToolCatalogDb.ps1`, `config/tool_catalog.json`): integer codes and atom lists; no boolean `Admin` left.
  - Show pages (Tool Explorer, ShowCM): `none` / `controlled` / `admin` in badge, filter, editor and run labels; a run of a code-2 or code-3 tool is never elevated by the page itself.
- Point O-1 (B) is unchanged unless the operator decides otherwise: the fast path checks the atom; the caller rule runs on the slow path and in the consistency check.
- Exit criterion addition: a test matrix over the section 9.2 borders (Medium -> Medium, High -> High, Medium -> High via DO, High -> Medium via DO, code 2 with listed and unlisted atom) passes in `go test` and Pester before deployment; rollback copy of `do.exe` in `scratch/`.## Absorbed Operator Remarks

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

> no, these are only "outer tool controls". however, if an elevated atom is called now, but its caller is admin, that would be ok. Getting complicated here. but i do not think there is anything wrong with a tool that is not admin to call a tool that is

(Operator, 2026-11-17; answer to "BCR tools tools.admin = 1?".)

> i did mean admin, not administrator. Non-administrators would possibly not even be shown admin tools by default. but that's just polish for later

(Operator, 2026-11-17; then option A: the direct caller of an elevated atom must be an admin tool; non-admin tools reach elevated atoms only through admin tools.)

> here is another choice that could make things easier: we currently haver admin (or not). how about a tri state choice: admin, controlled, (none). controlled would allow elevated atoms to be used. BCR would use that

(Operator, 2026-11-17; then option A inside CRP-343: tri-state plus declared atom list per controlled tool; "1,2,3 interna coding, text as visual equivalents on Show..."; encoding option A: 1 = none, 2 = controlled, 3 = admin.)

> 2 - ok, and also understood, including the (new) rule Medium->high. For High->medium that detour is unavoidable, and so is the rule
> 3 - Put such diagrams into the Implementation Docs!!! and similarly do this for the Requirements to illustrate the use cases.
> 3.2 - "carefully kill" legacy where you see it. In particular, if it is essentially doing the same thing with minimal differences.
> 6 - [...] port 9876 (or operator prompting) are the only gates to elevation -- that can always be accepted, provided the interactions are not UIUI (you know what i mean)

(Operator, 2026-11-17; source of sections 9.2 and 9.3.)
