# CRP-253 Implementation Plan (Draft)

## Phase 0 - Empirical Trial & Separation (Completed 2026-10-13)

1. Replicated workspace tree to `D:\Git_World` via `robocopy /E /XJ`.
2. Executed analysis on junctioning root vs hybrid child mounting; confirmed that root core and `LCM_*` repos must remain physical in Git Root (`D:\Git_Repositories`).
3. Purged all 19 root core assets and `LCM_*` infrastructure from `D:\Git_World`, leaving exclusively the 15 child application/utility repositories.
4. Created and executed `LCM_Inventory/tools/Initialize-GitWorld.ps1`, establishing `.agents/rules` junctions and Git global `safe.directory` for `D:/Git_World/*`.
5. Confirmed `D:\Git_Repositories` is untouched and 100% operational as-is.

## Phase 1 - Switch Design & Governance Controls

- Formalize `LCM_Mode.ps1` parameter contracts and linkage methods.
- Define whether mounting into Git Root occurs per repository or as a batch.
- Establish clean unmount / rollback procedures.

## Phase 2 - Tool

1. `LCM_Inventory\tools\LCM_Mode.ps1` with `-Off/-O`, `-Resume/-R`,
   `-Status/-S`, `-WhatIf`, `-h`; functions `Disable-LcmGovernance` and
   `Enable-LcmGovernance`.
2. Reuse the reparse-point-only guard from `Invoke-LcmJunctionCorrection.ps1`.
3. Log each transition; print the restart notice.
4. Session-start / pre-commit check that reports a non-norm world (visibility
   gap found on 2026-10-13).

## Phase 2b - Prototype World tooling (Specification section 3)

1. `New-PrototypeWorld -Crp <n> -Repos <list>`: governed-list and clean-tree
   checks, clone to `CRP-Proto-nnn`, `crp-nnn` branch, manifest with base
   commits, junctions to base for the rest.
2. `Add-PrototypeRepo`: guarded junction-to-clone swap, dependency listing.
3. `Sync-PrototypeFromBase` and a per-repo drift report.
4. `Close-PrototypeWorld`: reconcile (merge or PR), remove clones, restore
   junctions, fall back to production on failure.
5. Write enforcement: tool gate, ACL safety net (after trial), commit-gate
   refusal for base repos while a prototype is active.
6. Governed-repo list and clean-tree pre-check; onboard the 7 repos without an
   `origin` using the base folder as origin.

## Phase 3 - Activation (separate review gate; replaces the earlier root-junction migration)

The earlier step "move `D:\Git_Repositories` to world A and create a root
junction" is withdrawn because of the Phase 0 findings.

1. Quiesce VS Code, git, terminals, watchers.
2. Activate by repointing child `.agents\rules` junctions and linking
   Git_World children into Git Root as designed in Phase 1.
3. Validate: junction inventory, `LCM_AI` hashes unchanged, `Git_Root`
   prefix checks pass, restart notice shown.

## Trials before design freeze

- ACL read-only safety net on a scratch repo (git, hooks).
- Marker-rule test: which channels (`AGENTS.md`, `.agents`, `.copilot`) an
  agent session actually reads (VS Code behaviour unconfirmed).
- Clone of a repo with no `origin` and a local merge back.

## Verification

- `-WhatIf` on scratch; `-Off` then `-Resume` round trip with identical
  inventory; failure cases (physical dir at root path, already-OFF, hand
  rename); AST syntax gate (`RULE-PS-021`); Beyond Compare review before commit.

## Risks

- Real-path access to a world bypasses the switch and can write into the wrong
  world.
- Copied worlds carry live remotes until neutralized.
- Worlds diverge; promotion needs a reviewed path.
- Open sessions keep the old world until restarted.
- A write through a base junction before the swap lands in production.
- Registry (`proposals.json`) edits made in a prototype would conflict on
  merge; keep them in the base.
- Skewed base commits between clones added at different times.
- Junctioned base repos are also reachable by real path; tools must use the
  prototype world path.
