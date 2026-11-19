# Implementation Plan: CRP-343 - Intent-Level Elevation Driven By Tool Intents Table

Module: docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Implementation Plan CRP-343.md  
Purpose: Concrete changes of CRP-343 segment 2 and the design considerations behind segments 1 and 2.  
Path: LCM_Inventory/docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Implementation Plan CRP-343.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-19 10:14:39

---

## 1. Segment 1 (done 2026-11-17)

See Walkthrough section 2: per-atom decision in the Go daemon, caller key, explorer-token launch, policy export, mount worker atom.

## 2. Segment 2 Steps (one deployment)

| Step | Change                                   | Files                                                                 | Spec  |
|:----:|:-----------------------------------------|:----------------------------------------------------------------------|:------|
| 1    | Temporary migration tool                 | `tools/Invoke-LcmPermissionMigration.ps1` (new, deleted at Gate 2)    | T4    |
| 2    | Atom lists of `controlled` tools         | `tools.db` table + catalog JSON; `docs/DataDesign-*.md`               | T1 T2 |
| 3    | Policy export and consistency check      | `tools/Export-LcmElevationPolicy.py`, `Sync-LcmToolCatalogDb.ps1`     | T2 T3 |
| 4    | Daemon decision by caller value          | `src/do/elevation.go`, `callerid.go`, tests                           | T3    |
| 5    | Catalog writers on integers              | `tools/Update-ToolCatalog.ps1`, `tools/Sync-LcmToolCatalogDb.ps1`     | T1    |
| 6    | Show pages: words, filter, editor        | `assets/lcm-tool-explorer.js`, `assets/CM_CONTROL_HUB.html`           | T1    |
| 7    | Legacy daemon retirement, key transition | `tools/LcmDesktopDaemon.ps1`, `LcmSecurityGateway.ps1`, callers       | T3 T5 |
| 8    | Rules and adapters (ADMINMODE)           | RULE-ELEV-001/003/006/007, `.claude/rules`, hashes                    | T6    |
| 9    | Diagrams and use cases                   | `docs/Implementation.md`, `docs/Requirements.md`                      | T1-T3 |
| 10   | Tests of Specification section 3         | `src/do/*_test.go`, `tests/*.Tests.ps1`, node checks                  | Exit  |

Notes per step:
- Step 1: `-Report` writes the mechanical changes and the conflict list with a hash; `-Apply -ReportHash` applies the mechanical part and each conflict only with the operator's decision recorded in the report.
- Step 3: the sync runs the policy export (no manual step); the check reads a tool-call cross-reference of direct invocations (`&`, `-File`, `do.exe`, `Start-Process`) instead of text matches.
- Step 4: open operator point O-1 (fast path checks the atom only, or the caller's admin value on every elevating request); default as decided: B.
- Step 7 callers found 2026-11-18: `Invoke-InteractiveDesktop.ps1`, `Invoke-LcmAction.ps1`, `Register-LcmDesktopDaemon.ps1`, `Show-LcmDaemon.ps1`, `Test-GeneralReadiness.ps1`, `Test-LCMIncrementalGovernance.ps1`, `Update-ToolCatalog.ps1`, `modules/LcmStandardDisplay.psm1`, `Cmd/LcmDaemon.cmd`; each is migrated to the DO or removed, and listed in the Walkthrough. Tools posting to the daemon without `LcmDoClient.psm1` move to it (key); `Dismount-MacriumCurrentBaseline.ps1` delegation and `Invoke-LcmAction.ps1` reach elevated steps through registered atoms; last: `LCM_DO_REQUIRE_KEY=1`.
- BUG-348 segment 2 (daemon routes, CORS, task path, image identity, `gofmt`, version string) rides in the same daemon build.

### Step status (2026-11-18 23:44:31)

| Step | State                                                                                   |
|:----:|:----------------------------------------------------------------------------------------|
| 1    | replaced: the generator converts the levels itself (no separate migration tool needed)  |
| 2    | done: AllowedAtoms in the catalog, table `tool_atom_permissions` in tools.db            |
| 3    | done: policy export with levels and lists; open: export run by the catalog sync         |
| 4    | done: daemon 10.2.7 deployed (owner level 3, `callerDecision`)                          |
| 5    | done: generator 10.2.11, sync 10.2.5                                                    |
| 6    | done: Tool Explorer 10.0.3, catalog module 10.2.5; Control Hub shows no Admin column    |
| 7    | open: legacy daemon retirement and the 9 callers; key transition (`LCM_DO_REQUIRE_KEY`) |
| 8    | open: RULE-ELEV-001/003/006/007 (ADMINMODE)                                             |
| 9    | open: diagrams in `docs/Implementation.md`, use cases in `docs/Requirements.md`         |
| 10   | done for the core: Go call-table test, Pester levels/policy test; open: live tests per T2 row through the DO |
- Open (2026-11-19): retire candidates `LCM_Tools\tools\asus-debloater.ps1` and `SystemConfiguration\Source\asus-debloater.ps1` (kept: `SystemConfiguration\Source\Invoke-AsusDebloater.ps1`); 19 failing unit test cases surfaced by the new LCM_Inventory readiness gate; the remaining conflicts are 11 (Walkthrough section 11).
- Open as well: the 13 remaining conflicts of the consistency check (`data/tools/elevation_policy.json`, `violations`; 31 before 2026-11-19, Walkthrough sections 6 and 7) await step 7 (9 callers of the retired `Invoke-InteractiveDesktop.ps1`) and the keyless-caller migration (4 daemon lifecycle callers); the 5 individual cases are decided (Specification T4); BUG-348 daemon items; then CRP-361.
- Backups (operator rule 2026-11-18): `scratch/db-dumps/tools_db_before_CRP-343-s2_20261118_233300.sql`, `scratch/db-dumps/elevation_policy_before_CRP-343-s2.json`, `scratch/do-before-crp343-s2.exe`; deleted after the completion checks.
## 3. Deployment Order

1. All tests of Specification section 3 green on fixtures; rollback copy `scratch/do-before-crp343-s2.exe`.
2. Migration report to the operator; conflicts decided.
3. One step: migration apply, policy export, daemon deploy.
4. Live tests (decision, launch level, BCR regression); Gate 2.

## 4. Design Considerations (moved from the Specification, 2026-11-18)

The following sections are the previous Specification sections 4-9, unchanged in content; they are input for the "Rationale" of `docs/Implementation.md` and are absorbed there at completion.

### Previous binary consistency invariant (Specification section 2 until 2026-11-18)

- Consistency invariant (confirmed by the operator 2026-11-17, option A, see Absorbed Operator Remarks): an `elevated` atom must belong to a tool with `admin = 1`, and its **direct caller** must be a tool with `admin = 1`. A non-admin tool may call an admin tool; it reaches elevated atoms only through an admin tool. Example: `Invoke-MacriumDailyBcrBaseline.ps1` (admin 0) -> `Mount-MacriumLatestBaseline.ps1` (admin 1) -> elevated mount-worker atom. `tools.admin` is the tool property "admin", not the user's Administrators membership; the BCR tools stay `admin = 0`. No user-group check now; hiding admin tools from non-administrators is later polish.

### 4. Corollary Scope (operator, 2026-11-17)

1. **Consistency-check atom**: one atom verifies (a) every `tool_intents.elevated = 1` atom is owned by a tool with `tools.admin = 1` and is invoked directly only by tools with `tools.admin = 1` (real invocations only: `&`, `-File`, `do.exe`, `Start-Process`; a mere mention is not a call); (b) every privileged command (RULE-ELEV-003 list) inside a tool sits in an `elevated` atom. Violations fail the check; it runs in the readiness gates and at good morning.
2. **Temporary cleanup tool**: one-off tool that reports the current violations (first known case: `Invoke-MacriumBcrReview.ps1` `admin = 0` calling the `admin = 1` mount/unmount tools) and applies the operator-accepted corrections to `tools.db` (structural DB changes only after CRP acceptance, WORKPLAN D-22); retired after the clean state is reached.
3. **Atoms inside tools**: elevated steps are cut out of tools into separately dispatched atoms (registered intents), so a tool's non-elevated steps never run elevated.
4. **DO front-end / back-end elevation flow**: operator review of which component checks elevation and by which method (current state: section 5); target: decided in this CRP before implementation.

### 5. Current DO Elevation Flow (analysis 2026-11-17, read-only)

| Step | Component | What it does about elevation | Evidence |
|:---|:---|:---|:---|
| 1 | Caller (PowerShell tool, AI, Control Hub page) | Decides itself whether to ask for elevation (`-elevated` flag or `options.elevated`); no catalog lookup in code: no tool or module queries `tools.admin` or `tool_intents.elevated` (RULE-ELEV-006 is an AI behaviour rule only). | grep `tools/`, `modules/`: no match |
| 2 | DO front end `do.exe` (client) | Turns `-elevated` into `"elevated": true` in the JSON body; no check of any kind. | `src/do/client.go:51-98` |
| 3 | DO back end `do.exe daemon` on 127.0.0.1:9876 | `/execute` accepts any command string; no caller identity, no catalog lookup, no admin or intent check. The `elevated` flag is only logged and, in the async path, skips the direct-exe shortcut; it never changes the token. Every child inherits the daemon token. | `src/do/daemon.go:193-422` |
| 4 | Daemon start | Scheduled task `\LCM_DesktopDaemon_rgbig`, RunLevel **Highest**, running (PID 11692 since 08:50). So everything dispatched through DO runs elevated, with or without `-elevated`; this is why Beyond Compare shows `Administrator:`. A second task `\LCM_Daemon_InteractiveStarter` (RunLevel Limited, state Ready) has a malformed action path (`\ ...do.exe daemon\`). | `Get-ScheduledTask` |
| 5 | Exposure | Responses of display/API routes carry `Access-Control-Allow-Origin: *`. For `/execute` a browser preflight is refused (`OPTIONS` -> HTTP 405, no CORS headers; verified 2026-11-17), so JSON-typed cross-site POSTs are blocked. But `handleExecute` parses the body as JSON regardless of `Content-Type` and checks no `Origin`, so a preflight-free `text/plain` POST from any local browser page would still reach the elevated `/execute` [INFERRED from code; not tested because it would execute a command]. | `src/do/daemon.go:193-231`, `:741-744`; `OPTIONS` probe |

Consequence for the target state (corrected by the operator 2026-11-17): the only place that can enforce `tools.admin` / `tool_intents.elevated` is the back end, because the front end and the callers are not trustworthy. The daemon stays elevated (it cannot run non-elevated); it launches atoms with `elevated = 0` with a non-elevated token and atoms with `elevated = 1` elevated. Requests name an intent key, not a raw command. Neither launch mode may limit the operator's access: every launched task that needs operator responses runs visibly on the interactive Session 1 desktop.

Candidate methods for the non-elevated launch (design choice of this CRP, not decided): (a) the daemon duplicates the token of the operator's shell (`explorer.exe`, same session) and starts the atom with `CreateProcessWithTokenW` (medium integrity, same desktop); (b) a non-elevated launcher task (RunLevel Limited, interactive), e.g. the repaired `\LCM_Daemon_InteractiveStarter`; (c) the linked (filtered) token of the daemon's own elevated token. Side effect to respect: windows of elevated processes cannot be driven by non-elevated AHK atoms (UIPI), which is one more reason for CRP-344.
### 6. Caller Authentication (amendment, operator 2026-11-17)

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
### 7. Design Decisions (operator, 2026-11-17, chain A DOIT)

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

### 8. Deferred: Integrity of the Intent Table (operator 2026-11-17, "later")

- Exposure: the elevation decision trusts `tool_intents.elevated` and `tools.admin` (`data/tools/tools.db`) and the generated `data/tools/elevation_policy.json`. Both are writable by the operator account, so any local process of that account could grant itself elevation by adding or flipping a row. Until protected, the key (D2) and the fast/slow path (D4) limit who may ask, not what is registered.
- Candidate measures (to decide later): write access to `tools.db` and the policy limited to Administrators (ACL), changes only through a governed elevated atom; the daemon generates or verifies the policy itself (hash/signature recorded at catalog update) and refuses a policy that does not verify; every change to an `elevated` or `admin` value is logged and appears in BCR / Gate 2.
- Not part of the current CRP-343 implementation segment.

### 9. Revised Contract: Tri-State Tool Privilege (operator 2026-11-17, option A)

Refines the consistency invariant of section 2 and D3/D4 of section 7.

#### 9.1 Levels of `tools.admin`

Stored as integer (internal coding); Show* pages display the text.

| Code | Text | Runs at | May call elevated atoms |
|:---|:---|:---|:---|
| 1 | `none` | Medium | never |
| 2 | `controlled` | Medium | only through the DO (port 9876), and only the atoms in its declared atom list |
| 3 | `admin` | High, when dispatched as an elevated intent | other `admin` atoms directly (child inherits High) |

- `tool_intents.elevated` stays the atom-level authority: an `elevated = 1` intent must belong to a tool with code 3.
- Declared atom list: every `controlled` tool lists the elevated atoms it may call (catalog entry, projected into `tools.db`; script header `ADMIN DEPENDENCIES` per RULE-ELEV-007). These entries are the first "calls directly" edges of the tool-call xref table. Schema detail goes into the data design document during implementation.
- Comparisons use the ascending order: "may reach elevated atoms" = code >= 2.

#### 9.2 Elevation borders (operator confirmed 2026-11-17)

| Caller -> callee | Allowed path |
|:---|:---|
| Medium -> Medium | direct |
| High -> High | direct, only when the caller is an `admin` (3) tool |
| Medium -> High | only through the DO (port 9876) or a visible operator UAC prompt |
| High -> Medium | only through the DO (non-elevated launch with the explorer token); never as a direct child, which would inherit High |

- The only gates to High are port 9876 and a visible operator UAC prompt.
- UIPI: a Medium process cannot drive an elevated window; AHK atoms exist in both variants, or one atom is elevated only for the parameter set that needs it (intent `parameters`).

#### 9.3 Migration and first cases

- Data: `admin` 0 -> 1, 1 -> 3; then the reclassifications below. Catalog JSON (transition fallback) carries the same integer.
- `Invoke-MacriumBcrReview.ps1`, `Invoke-MacriumDailyBcrBaseline.ps1`, `Mount-MacriumLatestBaseline.ps1` -> 2 (`controlled`), atom lists: mount worker `Invoke-MacriumMountWorker.ps1`, `Set-LcmMachineRegistry.ps1`, `Dismount-MacriumCurrentBaseline.ps1` as each tool actually calls them.
- Consequences: the BCR baseline tool dispatches the mount worker and the registry atom through the DO itself; the `Mount-MacriumLatestBaseline.ps1 -ImagePath` hop stays only as the operator's manual mount entry if it is not a duplicate; the legacy `-ElevatedWorker` entry of `Invoke-MacriumDailyBcrBaseline.ps1` is removed; further legacy duplicates found on the way are removed and listed (operator 2026-11-17, "carefully kill legacy").
- Rules: RULE-ELEV-001 / 003 / 006 / 007 state the three levels and the border table (RULE-AUTH-002 sync).

#### 9.4 Point O-1 (decided: B, operator 2026-11-17)

- Decision B: D4 stays as decided; the fast path checks the atom only; the caller rule is enforced by the consistency check (static) and on the slow path. Candidate A below is not implemented.

- D4 fast path checks only the atom; the caller rule is enforced statically (consistency check) and at runtime only on the slow path. Candidate: run the caller check (direct caller tool code >= 2 and atom in its list) on every request that would elevate; elevated requests are rare (mount, registry, dismount), so the cost is small.

#### 9.5 Exit criteria additions

- Consistency check with the three levels: zero violations.
- Show* pages display `none` / `controlled` / `admin`.
- Diagrams: call chains and the elevation decision in `LCM_Inventory/docs/Implementation.md`; use cases in `docs/Requirements.md` (operator 2026-11-17).

#### 9.6 Delivery: data and border enforcement in one segment (operator 2026-11-18)

- The integer migration of `tools.admin` and the enforcement at every elevation border ship in the same segment and are deployed together; there is no intermediate state with tri-state data and boolean code.
- Reason (verified 2026-11-18): the readers compare against the binary coding. `src/do/elevation.go:112` (`ToolAdmin != 1` = catalog error) and `:121` (`admin == 1`), `tools/Export-LcmElevationPolicy.py:78/83` (`admin != 1`, `admin == 1`), the Tool Explorer (`assets/lcm-tool-explorer.js`, `t.Admin` truthiness and `true`/`false` values in badge, run, filter, editor). With migrated data alone, every `none` tool (1) would read as admin and every `admin` tool (3) as a catalog error.
- Border points enforced in this segment (section 9.2 table):
  - DO back end (`src/do/elevation.go`, `callerid.go`): an elevated atom is granted only when its owning tool has code 3 and the direct caller is code 3, or code 2 with the atom in its declared list; every other request runs Medium. High -> Medium launches keep the explorer token (D1).
  - Policy export and consistency check (`Export-LcmElevationPolicy.py`): the three levels, the declared atom lists, and the violation kinds for a code-2 tool calling an atom not in its list or calling it directly instead of through the DO.
  - AHK border (`modules/LcmAhkAtoms.psm1`): the elevation-match check stays; an elevated AHK atom is reached only through the DO.
  - Catalog writers (`tools/Update-ToolCatalog.ps1`, `Sync-LcmToolCatalogDb.ps1`, `config/tool_catalog.json`): integer codes and atom lists; no boolean `Admin` left.
  - Show pages (Tool Explorer, ShowCM): `none` / `controlled` / `admin` in badge, filter, editor and run labels; a run of a code-2 or code-3 tool is never elevated by the page itself.
- Point O-1 (B) is unchanged unless the operator decides otherwise: the fast path checks the atom; the caller rule runs on the slow path and in the consistency check.
- Exit criterion addition: a test matrix over the section 9.2 borders (Medium -> Medium, High -> High, Medium -> High via DO, High -> Medium via DO, code 2 with listed and unlisted atom) passes in `go test` and Pester before deployment; rollback copy of `do.exe` in `scratch/`.

## 5. Absorbed Operator Remarks (moved from the Specification, 2026-11-18)

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

(Operator, 2026-11-17; correction of the DO flow analysis.)

> i will do refresh on BCR tabs myself until we have this sortedout, no problem.
> your remark "I didn't port the CRP-309 tokens. They wouldn't stop a web page: most actions need no token, the admin tier accepts a caller name the page writes itself, and /api/token gives a token to anyone. Real caller authentication belongs to CRP-343."
> required that 343 is amended accordingly.
> What will happen now when i refresh an existing ShowXXX window? will it fail?
> more questions to the AHK crp:
> - is it mentioned in the list of external tools? we must check that all tools we used are documented.

(Operator, 2026-11-17; caller authentication amendment.)

> no, these are only "outer tool controls". however, if an elevated atom is called now, but its caller is admin, that would be ok. Getting complicated here. but i do not think there is anything wrong with a tool that is not admin to call a tool that is

(Operator, 2026-11-17; answer to "BCR tools tools.admin = 1?".)

> i did mean admin, not administrator. Non-administrators would possibly not even be shown admin tools by default. but that's just polish for later

(Operator, 2026-11-17; then option A: the direct caller of an elevated atom must be an admin tool.)

> here is another choice that could make things easier: we currently haver admin (or not). how about a tri state choice: admin, controlled, (none). controlled would allow elevated atoms to be used. BCR would use that

(Operator, 2026-11-17; then option A inside CRP-343: "1,2,3 interna coding, text as visual equivalents on Show..."; encoding A: ascending.)

> 2 - ok, and also understood, including the (new) rule Medium->high. For High->medium that detour is unavoidable, and so is the rule
> 3 - Put such diagrams into the Implementation Docs!!! and similarly do this for the Requirements to illustrate the use cases.
> 3.2 - "carefully kill" legacy where you see it. In particular, if it is essentially doing the same thing with minimal differences.
> 6 - [...] port 9876 (or operator prompting) are the only gates to elevation -- that can always be accepted, provided the interactions are not UIUI (you know what i mean)

(Operator, 2026-11-17.)

> OK, but the complicated change is not the data change, but the code: the admin limit the propagation in mixed elevation boarder crossings. That must be done at the same time!

(Operator, 2026-11-18; source of the "data and enforcement together" invariant.)

> Reading the Specs for 343 -- my disposition is "accepted with (massive) changes"
> [...]
> "Current data already conflicts with the consistency invariant" can this be automatically fixed (one time? in case of conflicts after consult?) and admin=0 is not even defined, as the range is 1-3, or is this only related to the "temporaryclean up tool? Who will run this? when do we delete it?
> ##5 section: this errfectively defines 343 as self blocking, not a good goal. It does not distinguish a known solution path from a real problem. Consequences, as opposed to this, shows no problem area.
> ##6 is the bad news part (what for?). It cites crp-309 which is not "open business". If we override a previous decision, that is totally normal. Why should we "port a finished CRP"?? I see that part of the just as the definition of work to be done to solve the problems, and maybe requireing rule revisions that need to be done.
> In Target state additions, the discussion is back to being constructive: 1-5 are correct paths to our goal. What it does not say: are the crp 309 items lifted here, or incomplete?
> what crp is being started with the section "Candidate measures (to decide later)"? The goals it must fulfill should be suggested already, right here
> ### 9 that looks good , but 9.1 and  9.2 are bit hard to read.
> What immediately sticks out is the name "none" for an admin value 1. I would propose "granted" or another term i just can't find at this time.
> (how is 0 represented as text - "TBD"?)
> we should have a simple table that also avoids the new teminology bridges Medium and High and only use the Permission words  "granted", controlled, admin to make it more readable.
> "The only gates to High are port 9876 and a visible operator UAC prompt." Could you rephrase that so it does not sound like a reason to avoid port 9876? the opposite is the case: i would like to "force" every tool call through either DO or DOsimple (we have a CRP for the latter??)
> 9.4 new term "caller tool code" is probably just the admin value? if so, use that, as in "the tools 'admin' value. if you have a short and much better name, you are allowed to use that instead.
> 9.5 should specify which test are actually done by you to check the design's implementation
> 9.6 is likely to confuse AI processes down-hill (later), because it really does not document the Specification goals. At best, it is a collection of design decisions for Implementation docs, but only in a highly condensed form. Remove such material from the Specification docs in the future; what you could consider is a fourth document named "Design considerations.md" for later absorption into Implementation "Rationale", but the simplest choice is put it at the end of the Implementation Plan?
> Currently, that plan is almost empty of meaning.
> Walkthrough: since you are/should be already using a fixed witdth font, tabular data would be readable if formatted properly. Do that. I hate spaghetti text in tables
> regarding test coverage: i really think Claude Code can do better than what you describe here.

(Operator, 2026-11-18; review of this Specification. Resolution: section 2 T1-T6 and section 3; the previous sections 5-9 moved to the Implementation Plan, "Design considerations".)

> as long as no other "hidden" actions on my side are not brought to my attention, the question you posed  on REQ-WINV.014 is YES.  and please present the guided questions for 355 and ACCEPT 343 (including the Section 8 exemption)

(Operator, 2026-11-18; acceptance of this Specification.)

> not relevant to LCM methodology, but please move the 343 Spec section on "Absorbed Operator Remarks", as defined, to its implementation plan. No need to reopen the CRP for that.

(Operator, 2026-11-18.)
