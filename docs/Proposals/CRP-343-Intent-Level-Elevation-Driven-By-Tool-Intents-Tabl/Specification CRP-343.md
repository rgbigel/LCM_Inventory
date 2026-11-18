# Specification: CRP-343

Module: docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification CRP-343.md  
Purpose: Intent-Level Elevation Driven By Tool Intents Table  
Path: LCM_Inventory/docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Specification CRP-343.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-18 20:24:06

```yaml
CRP-ID: CRP-343
Title: Intent-Level Elevation Driven By Tool Intents Table
Scope: LCM_Inventory
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-18 20:24:06
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: 7
App-ID: None
```

---

## 1. Executive Summary & Intent

- Elevation is decided per atom (registered intent), not per tool. A tool's permission (`tools.admin`) says which elevated atoms it may use and how; the atom's flag (`tool_intents.elevated`) says whether it runs elevated.
- Segment 1 (2026-11-17, done): the DO daemon decides elevation per atom, authenticates callers, starts everything else non-elevated. Segment 2 (next): the four permission values and their enforcement at every elevation border, in one step.
- Operator disposition 2026-11-18: Specification accepted with (massive) changes; this text is the revision.
- Review: this Specification and the Implementation Plan (segment 2 steps, design considerations at its end). Walkthrough: segment 1 evidence only.

## 2. Gate 0 Contract

### Target State

T1 Permission values of `tools.admin` (integer internally; Show pages display the word):

| Value | Word         | Its own atoms run             | Elevated atoms it may use                         |
|:-----:|:-------------|:------------------------------|:--------------------------------------------------|
| 0     | `TBD`        | non-elevated                  | none (not classified yet; reported by the check)  |
| 1     | `granted`    | non-elevated                  | none                                              |
| 2     | `controlled` | non-elevated                  | only the atoms in its declared list, via the DO   |
| 3     | `admin`      | as flagged (`elevated` 0/1)   | any elevated atom of an `admin` tool              |

T2 Calls across permissions:

| Caller       | Callee                              | Allowed path                         |
|:-------------|:------------------------------------|:-------------------------------------|
| any          | non-elevated atom                   | direct (from `admin`: via the DO)    |
| `admin`      | elevated atom of an `admin` tool    | direct                               |
| `controlled` | elevated atom in its declared list  | via the DO only                      |
| `controlled` | elevated atom not in its list       | never                                |
| `granted`    | elevated atom                       | never                                |
| `TBD`        | elevated atom                       | never                                |

- "From `admin`: via the DO": a non-elevated atom started directly by an elevated process would inherit the elevation; the DO starts it non-elevated.
- Elevation is reached through the DO (port 9876). Target: every tool call goes through the DO or DOsimple; a visible operator UAC prompt is only the fallback when the DO is not available.
- An elevated atom belongs to an `admin` tool; the declared list of a `controlled` tool names the atoms it uses (catalog entry and script header `ADMIN DEPENDENCIES`, RULE-ELEV-007).

T3 Enforcement: the DO back end grants an elevated atom only when the caller's admin value allows it (T2); front end and callers are not trusted. The caller is authenticated by a secret a web page cannot obtain, never by a self-declared field (decided 2026-11-17, implemented in segment 1).

T4 One-time correction of the current data (temporary cleanup tool, run by Claude):
- Mechanical cases are applied automatically: value 0 -> 1 (`granted`), 1 -> 3 (`admin`); the BCR tools (`Invoke-MacriumBcrReview.ps1`, `Invoke-MacriumDailyBcrBaseline.ps1`, `Mount-MacriumLatestBaseline.ps1`) -> 2 (`controlled`) with the atom lists their real calls show.
- Every other conflict (an elevated atom called from a tool whose value would not allow it) is listed in a report; the operator decides each case before it is applied (report -> confirmation -> apply, as in CRP-355).
- After the run, 0 means `TBD`: new tools land there until classified.
- The tool is deleted in the same completion in which the consistency check first reports zero violations (Gate 2 of segment 2).

T5 Legacy: the CRP-309 caller model (token tiers, self-declared `caller`, `POST /api/token` for everyone) is superseded by T3; it is not ported. Its PowerShell daemon (`tools/LcmDesktopDaemon.ps1`, `modules/LcmDaemon/Classes/LcmSecurityGateway.ps1`) and callers still using it are migrated to the DO and removed where they only duplicate it (operator 2026-11-17: "carefully kill legacy").

T6 Rules: RULE-ELEV-001 / 003 / 006 / 007 state the four values, the call table T2 and DO routing by intent (RULE-AUTH-002 sync).

### Invariants and Exit Criteria

- No privileged command (RULE-ELEV-003 list) runs outside an elevated atom.
- Non-interactive runners are never blocked by UAC (RULE-ELEV-002); elevated consoles keep `-NoExit` (RULE-ELEV-005).
- Tasks that need operator responses stay visible on the operator's desktop, elevated or not.
- Data and enforcement change together: no deployed state with four values in the data and two in the code.
- The elevation decision is one function that the `do.exe` client can also call (CRP-361, DO-Little, planned back-to-back): no design that forces simple same-rights calls through the daemon.
- Exit: consistency check zero violations; every row of T2 proven by a test (section 3); Show pages show the words of T1; rules and adapters synced.

### Explicit Non-Goals

- Protecting the intent table against changes by the operator account (follow-up, section 4).
- Changing BCR, Beyond Compare or AHK behaviour (CRP-344, CRP-345, CRP-346, completed).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Tests Claude Runs For Segment 2

| Area                  | Test                                                                                | Tool          |
|:----------------------|:------------------------------------------------------------------------------------|:--------------|
| Decision table        | every T2 row x key present/absent x composite command -> grant / deny with reason   | `go test`     |
| Live decision         | same matrix against the deployed daemon through `GET /api/elevation/verify`         | Pester        |
| Live launch level     | one probe atom per row started through the DO reports its integrity level           | Pester        |
| Authentication        | forged `caller`, no key, browser `Origin`, wrong listener -> refused and logged     | go + Pester   |
| Migration             | fixture `tools.db`: mapping, BCR lists, rerun idempotent, conflicts only reported   | Pester        |
| Confirmation          | apply refuses an unconfirmed or changed conflict report, nothing written            | Pester        |
| Consistency check     | one fixture per violation kind; zero findings on a clean fixture                    | pytest        |
| Catalog writers       | `Update-ToolCatalog.ps1` / `Sync-LcmToolCatalogDb.ps1` keep integers and lists      | Pester        |
| Show pages            | word per value, filter per value, editor offers the four values                     | node          |
| Show page run         | a run never adds `-Elevated` by itself; the DO decides                              | node          |
| BCR regression        | dry-run of mount, registry and dismount atoms from the `controlled` BCR tools        | Pester        |
| Legacy removal        | no remaining caller of removed scripts (catalog xref + search)                       | Pester        |

- Before deployment: all green, rollback copy of `do.exe` in `scratch/`. After deployment: live rows re-run; operator live test at Gate 2.

## 4. Follow-up: Integrity Of The Intent Table (separate CRP after segment 2)

The elevation decision trusts `tools.db` and the generated `elevation_policy.json`, which the operator account can write. Goals for that CRP:
- G1 Only a governed elevated atom can change `admin` or `elevated` values.
- G2 The daemon refuses a policy whose hash does not match the one recorded at the last governed catalog update.
- G3 Every change of an `admin` or `elevated` value is logged and appears as a review candidate at BCR / Gate 2.

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
