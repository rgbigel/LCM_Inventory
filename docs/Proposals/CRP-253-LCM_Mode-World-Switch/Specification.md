# CRP-253: LCM_Mode - World Switch for Governance Off / Resume

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-253` (registered in proposals.json) |
| **Lifecycle State** | `SUGGESTED` |
| **Origin Repository** | `LCM_Inventory` |
| **Date** | 2026-10-08 |
| **Related** | `CRP-251` (Sandboxed Prototyping Mode), `RULE-LCM-020` |

## Problem

- Governance (rules, entry points, commit gate) must be switchable off during
  major method realignment and during prototype runs of an LCM variant, and back
  on afterwards, without harming the physical storage in `LCM_AI`.
- On 2026-10-01 `D:\Git_Repositories\.agents` was renamed to
  `.agents.disabled` outside any tool. Nothing detected it, nothing restored it,
  and it persisted for a week.
- Rules reach agents through several independent channels (verified 2026-10-08):
  - `AGENTS.md` / `GEMINI.md`: physical files in the root and in child repos;
    child copies differ in content.
  - Junctions: root `.agents`, `.copilot`, `.github\agents` to `LCM_AI`;
    child `.agents\rules` to `LCM_AI\.agents\rules`.
  - Inside `LCM_AI\.copilot`, `Rules`, `Atoms` and `Methods` are junctions to
    `LCM_AI` (they stay live regardless of any root switch).
  - `.githooks\pre-commit` (commit gate; `core.hooksPath = .githooks`) is
    physical and independent of `.agents`.
  - `.vscode`, `.mcp.json`, `.venv` are physical and carry no rules.
- A root `.agents` junction alone therefore cannot switch governance off:
  the physical entry points and the commit gate remain active.

## Proposed Architecture ("World Switch") & Analysis Insights

### 1. Empirical Analysis Findings (2026-10-08 Trial)
An exhaustive analysis demonstrated that replacing the entire Git Root (`D:\Git_Repositories`) or all internal folders with junctions to an external world is broken:
- **Root Git Tracking (`typechange`)**: `D:\Git_Repositories` tracks `.github/`, `.githooks/`, `.vscode/`, `docs/`, and `LCM_Tools/` in Git. Converting them to junctions creates permanent `typechange` index conflicts in Git for Windows.
- **Machine Registry `Git_Root` Mismatch**: LCM tools resolve `$gitRoot` via `HKLM:\...\Environment\Git_Root` (`D:\Git_Repositories`). If target paths resolve to `D:\Git_World\...`, path prefix boundary checks (`$path.StartsWith($gitRoot)`) fail across security and search gates.
- **Chained Junction Failures**: Repositories already contain internal junctions (`.agents/rules`, `.agents/rules`, BCR scratchpads). Nesting parent junctions creates reparse-point loops and depth exceptions in recursive tools.
- **IDE File Watchers Disconnect**: Windows `ReadDirectoryChangesW` APIs do not propagate change events across junction boundaries into the open IDE root.

### 2. Refined Hybrid Architecture
To make the World Switch functional without breaking Git or LCM governance:
- **Physical in Git Root**: Root repository files (`.git`, `docs`, `LCM_Tools`, config) and all `LCM_*` infrastructure repositories (`LCM_Inventory`, `LCM_AI`, `LCM_Shared`, `LCM_Supervision`, `LCM_Backup`) MUST remain physical folders in `D:\Git_Repositories`.
- **Offloaded to Git World**: Detached child application and utility repositories (`HaSSD06`, `VolumeInventory`, `BootEntryManager`, etc.) physically reside in `D:\Git_World`.
- **Child Governance Pre-linking**: Each offloaded child repo in `D:\Git_World` is adjusted via `Initialize-GitWorld.ps1`, establishing `.agents/rules` junctions back to the canonical hub in Git Root and configuring Git global `safe.directory`.
- **Linkage Switch**: A future operational switch determines how and when child application repositories in `D:\Git_Repositories` are linked to `D:\Git_World`. Git Root remains untouched until this switch is activated.

### 3. Prototype World (`CRP-Proto-nnn`) - merged design conclusions (2026-10-08)

A prototype is a per-CRP world built by a tool, using branches for content and
junctions for everything the CRP does not touch. It lives outside Git Root and
never replaces the physical Git Root assets (section 2 still holds).

1. **Governed repos only.** The tool operates on an explicit governed-repo list
   and refuses anything else with a message. Non-governed repos are never
   junctioned or copied; if one is needed it is onboarded first.
2. **Clean-tree precondition.** At entry and at every later addition each
   repo must be clean (no tracked changes, no detached HEAD, nothing
   unpushed when a remote exists). Ignored runtime content (logs, `.agents`,
   `.copilot`, `LCM_Inventory\data` state) is not cloned; the tool lists it and
   creates or links it separately. Example: `RollingCalendar` currently has 4
   uncommitted files and must be committed or stashed before joining.
3. **Clones, not worktrees.** Each touched repo is a full local `git clone`
   with its own `.git`, a `crp-nnn` branch and the base commit recorded in the
   prototype manifest. A worktree is rejected because its `.git` file points
   at the authoritative repo, so branch, prune and reset operations in the
   prototype would act on it. Repos without an `origin` use the base folder as
   origin. Shared clones (`--shared`) are rejected (gc of the base can corrupt
   them).
4. **Junction-to-base by default.** Repos the CRP does not touch appear in the
   prototype world as junctions to the single base repo, so the world is
   complete from the start.
5. **Mid-prototype additions** (`Add-PrototypeRepo`): verify clean base, record
   its commit, clone, create `crp-nnn`, swap that one junction for the clone
   in a single guarded step, refuse when any process holds the path open, and
   list dependent repos (for example `LCM_Shared`).
6. **Write enforcement.** A junction is transparent, so a write through it
   lands in the base before anything can intervene. Enforcement is therefore:
   (a) governed tools call the add step before writing in a junctioned repo,
   (b) read-only ACLs on the base repos while a prototype is active as a
   safety net (untested), (c) the commit gate refuses commits in a base repo
   while a prototype is active. Writes made before a swap are detected by
   comparing the base against the recorded commit.
7. **Base changes during a prototype** (`Sync-PrototypeFromBase`): base fixes
   are committed in the base first, then fetched and merged into `crp-nnn`
   (the base is an ordinary remote of each clone). Conflicts stop the tool.
   A drift report (commits behind, overlapping files) is available per repo.
   A hotfix needed in the base immediately is cherry-picked from the prototype
   branch so the next sync merges cleanly.
8. **Registry stays in the base.** `proposals.json`, review receipts and
   `docs\Proposals` are edited only in the base to avoid merge conflicts.
9. **Reconciliation and cleanup** are one operation: merge or PR per repo
   (local merge for repos without a remote), then remove clones, restore
   junctions and return to the norm. A failed cleanup must never leave rule
   links pointing at a deleted prototype; fall back to the production target.
10. **Naming.** `D:\Git_World` is the offloaded non-LCM child store. The
    per-CRP world is named `CRP-Proto-nnn` to avoid confusion.
11. **Where "rules changed away from production" live.** The prototype clone of
    `LCM_AI` holds the prototype rules. The switch point is the child
    `.agents\rules` junction (the 15 in Git_World and those in Git Root),
    repointed to the prototype rules hub and back.

### 4. Alternatives considered

| Alternative | Verdict |
|---|---|
| Root `D:\Git_Repositories` as junction to a world folder | Rejected by the 2026-10-08 trial (section 1). |
| Ghost copy of Git Root acting on Git World | Duplicates registries; data not isolated; superseded by the prototype world. |
| Branch-only (no clone) in the base repo | Shares one working directory; no concurrent prototypes; prototype acts on the authoritative repo. |
| Super-junction `D:\LCM_Active` that all rule links resolve through | Attractive (one switch), but conflicts with requirement 2 (hub physical in `LCM_AI`), the `Git_Root` registry prefix checks and the correction tool's no-reparse-target guard. Not adopted; revisit after the open questions below. |
| `.agents` rename to `.agents.disabled` | The ad hoc method that went unnoticed for a week. Replaced by the tool. |

## Interface: `LCM_Mode`

| Parameter | Alias | Meaning |
|---|---|---|
| `-Off` | `-O` | Repoint child repositories to the configured prototype / off world. |
| `-Resume` | `-R` | Repoint child repositories to the production world. |
| `-Status` | `-S` | Report the active world; read-only. |
| `-WhatIf` | | Preview. |

Two exported functions back the script: `Disable-LcmGovernance` and
`Enable-LcmGovernance`. Both are idempotent.

## Requirements

1. Root core repository files and `LCM_*` infrastructure repositories remain physical in Git Root and are never converted to junctions.
2. The canonical rules hub remains physically anchored at `D:\Git_Repositories\LCM_AI\.agents\rules`.
3. Child repositories in `D:\Git_World` must be pre-linked via `Initialize-GitWorld.ps1` before mounting.
4. Git Root remains working as-is until the activation switch is explicitly invoked.
5. Every switch is logged (time, user, from, to).
6. After a switch, the tool reports that open editors and agent sessions must be restarted.

## Settled & Open Questions

- **Settled (Question 7 - Git Junction Behavior)**: Settle as **hybrid only**. Junctioning tracked root folders fails (`typechange`), but junctioning untracked/ignored child repositories is safe because they are covered by `/*/` in `.gitignore`.
- **Open Question 1**: Does VS Code / Copilot load the root `.agents`? Unconfirmed (docs search failed); a marker-rule test in a prototype world would settle it.
- **Open Question 2**: Should the commit gate (`.githooks`) follow the switch (off in world B) or stay on in every world?
- **Open Question 3**: Do `AGENTS.md` / `GEMINI.md` remain full indexes per world, or become tiny pointers? Child copies currently differ.
- **Open Question 4**: Relation to `CRP-251`: LCM_Mode as the switching mechanism that CRP-251 builds its sandbox entry/exit on, or merged into one proposal?
- **Open Question 5**: Scope outside the root (`D:\OneDrive\cmd`, `C:\Temp`, user-level `~\.copilot`): out of scope, or included?
- **Open Question 6**: Promotion path from world B back to A (normal CRP with review?). Proposed: merge or PR per repo, each under the normal review gate.
- **Open Question 7**: Where does the governed-repo list live (`proposals.json`, a new manifest, or the repo inventory)?
- **Open Question 8**: Is "registry edited only in the base" acceptable, given that a CRP cannot then be created inside a prototype?
- **Open Question 9**: Manual sync only, or a session-start warning when drift exists?
- **Open Question 10**: Does the ACL safety net (read-only base repos during a prototype) work with git and the hooks? Needs a scratch trial.
- **Open Question 11**: One active prototype at a time (assumed), or several?
- **Open Question 12**: Title and `details` in proposals.json describe the Git World mounting only; update them if the prototype-world scope is accepted here.

## Non-Goals

- No bypass of governance inside the live world A.
- No change to the contents of `LCM_AI` rules.
- No switching of `.mcp.json` or `.venv` beyond what a world contains.
