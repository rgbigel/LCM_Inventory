# Specification: CRP-369

Module: docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Specification CRP-369.md  
Purpose: Single Source For VS Code Settings  
Path: LCM_Inventory/docs/Proposals/369_CRP-Single-Source-For-VS-Code-Settings/Specification CRP-369.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: Verified  
Date: 2026-11-19 16:19:56

```yaml
CRP-ID: CRP-369
Title: Single Source For VS Code Settings
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-19 16:19:38
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

- Finding (2026-11-19, read-only check): 9 different `.vscode/settings.json` versions. The root file has 28 settings; the repository copies have 4-12 and are mostly stale partial copies of it. `Solution.code-workspace` has `D:/Git_Repositories` as the only workspace folder for the repositories, so VS Code applies only the root file (plus the workspace file's settings) to every repository file; the repository copies are used only when a repository is opened on its own.
- Operator decision 2026-11-19: option A (one source); OutlookVBAConversion is ignored entirely (not LCM governed; the operator may drop Outlook).

## 2. Gate 0 Contract

### Target State

T1 One source for VS Code settings: the root `.vscode/settings.json` holds the resource settings for all repositories; settings that belong to the workspace as a whole stay in `D:\VSCode-Workspaces\Solution.code-workspace`.

T2 The repository copies are deleted: AuthorizeMasterUser, BGMSAMVInv, BackgroundModifier, BootEntryManager, LCM_AI, LCM_Shared (tracked) and VolumeInventory (untracked).

T3 A setting that exists only in a repository copy and is still wanted moves into the root file before the copy is deleted; no setting is lost silently.

### Invariants and Exit Criteria

- Line endings stay correct for a repository opened on its own: `.gitattributes` (BUG-365) normalizes on commit.
- Exit: no `.vscode/settings.json` below the git root except the root one and OutlookVBAConversion's; the root file parses (JSONC); every key that existed only in a deleted copy is listed in the Walkthrough with its disposition (moved / obsolete).

### Explicit Non-Goals

- OutlookVBAConversion (untouched, operator 2026-11-19).
- `.vscode` files other than `settings.json` (launch, tasks, extensions).
- Junctions for `.vscode` (option C rejected).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Relation

- Planned together with the elimination of the JSON copies of SQLite tables (operator queue item 3).

## Operator Decisions (2026-11-19 17:32:57)

- The two keys that exist only in the AuthorizeMasterUser copy (`powershell.pester.pesterVersion`, `powershell.scriptAnalysis.enable`) are dropped with the copy.
