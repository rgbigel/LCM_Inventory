# Specification: BUG-338

Module: docs/Proposals/BUG-338-Repository-Agents-Folders-Not-Junctioned/Specification.md  
Purpose: Every repository's `.agents` must be a junction to `LCM_AI\.agents`; replace the real folders (holding only a `rules` junction) and delete the stale tracked `LCM_Inventory/.agents/ACTIVE_SESSION.md`.  
Path: LCM_Inventory/docs/Proposals/BUG-338-Repository-Agents-Folders-Not-Junctioned/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.7.4
Status: Registered (DOIT)  
Date: 2026-11-16 17:16:26

```yaml
Bug-ID: BUG-338
Title: Repository Agents Folders Not Junctioned
Scope: Git_Repositories
Version: 10.7.4
Affected-Repos: [LCM_Inventory, LCM_Shared, LCM_Supervision, LCM_Tools, AuthorizeMasterUser, BackgroundModifier, BGMSAMVInv, BootEntryManager, HaSSD06, HaSSD06_Inventory, InstallFonts, MacriumTemplateUpdater, MSG file conversion, NextBootTray, OneDriveMaintenance, OutlookVBAConversion, ReEnableRadeonRx580, RollingCalendar, SystemConfiguration, TimeStamper, VolumeInventory]
Severity: Medium
Status: Pushed
Root-Cause: Repositories were scaffolded with a real `.agents` folder containing only a `rules` junction instead of a junction of the whole folder; LCM_Inventory additionally tracks a stale `.agents/ACTIVE_SESSION.md` (CRP-164 era, 2026-10-13) and ignores only `.agents/rules/`.
Plan-State: pushed
Progress-State: pushed
```

---

## 0. Registration Note

Found by the operator at the start of the 2026-11-16 baseline review; registered and fixed by Claude in DOIT (operator: "do the junction changes now").

## 1. Gate 0 Contract

- **Target State**: In every repository directly under `D:\Git_Repositories` that has a `.agents` entry (except the owner `LCM_AI`), `.agents` is a junction to `D:\Git_Repositories\LCM_AI\.agents`; the stale `LCM_Inventory/.agents/ACTIVE_SESSION.md` is deleted and LCM_Inventory ignores `.agents/` like the other repositories.
- **Exit Criteria**: (1) every such `.agents` reports `LinkType Junction`, target `D:\Git_Repositories\LCM_AI\.agents`; (2) `.agents\rules` resolves to the canonical rules in each; (3) `git status` of LCM_Inventory shows only the deletion of `.agents/ACTIVE_SESSION.md` and the `.gitignore` change; the other repositories show no change (`.agents/` already ignored).
- **Explicit Non-Goals**: `LCM_AI\.agents` (physical owner) and the root `D:\Git_Repositories\.agents` (already a junction) unchanged; no change of scaffold templates under this BUG (checked separately); no content change inside `.agents`.

## 2. Findings (2026-11-16)

- 19 repositories: real `.agents` folder with only `rules` (junction to `LCM_AI\.agents\rules`); `.agents/` git-ignored.
- LCM_Inventory: real folder with `rules` junction plus tracked `ACTIVE_SESSION.md`; `.gitignore` line 39 ignores only `.agents/rules/`.
- OneDriveMaintenance: junction to `D:\Git_Repositories\.agents` (itself a junction to `LCM_AI\.agents`); repointed directly for uniformity.

## 3. Acceptance

- 2026-11-16 17:16:26: ACCEPTED by the operator (Rolf) in the running baseline BCR review (Gate 2 disposition). Ledger stays `verified` until `COMPLETE` (local commit incl. the staged deletion and the `.gitignore` change).
- Warning recorded: since the junctions, every repository's `.agents\ACTIVE_SESSION.md` is the live file; deleting it anywhere deletes the original (happened once on 2026-11-16, restored by Claude).
