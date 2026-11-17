# Specification: BUG-340

Module: docs/Proposals/BUG-340-New-LCM-Proposal-Placeholder-Slug-and-Version-Defe/Specification.md  
Purpose: New-LCM_Proposal scaffolds unmarked placeholder documents, silently truncates the bundle slug and stamps a stale LCM version; fix all three.  
Path: LCM_Inventory/docs/Proposals/BUG-340-New-LCM-Proposal-Placeholder-Slug-and-Version-Defe/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.7.4
Status: Registered (DOIT)  
Date: 2026-11-16 17:16:26

```yaml
Bug-ID: BUG-340
Title: New-LCM_Proposal Placeholder Slug and Version Defects
Scope: LCM_Inventory
Version: 10.7.4
Affected-Repos: [LCM_Inventory]
Severity: Medium
Status: Registered
Root-Cause: (1) Implementation_Plan.md / Walkthrough.md are scaffolded with generic text that reads like content and carries no placeholder marker, so no gate or reviewer can tell an empty plan from a real one; (2) ProposalManager.psm1 line 283 cuts the slug at 50 characters without notice, so a bundle folder created beforehand under the full title slug is not found and a second folder with a placeholder spec is created; (3) lcm_version is read from LCM_Inventory/data/inventory.json (workspace_ai_baseline.GlobalLCMVersion, refreshed only by an audit) instead of the authority LCM_AI/.agents/version.json.
Plan-State: suggested
Progress-State: undecided
```

---

## 0. Registration Note

Found by Claude on 2026-11-16 while registering BUG-338, CRP-339 and this BUG (folders `...-Executi`, `...-Host-Bindin`, `...-Version-Defe`; recorded version 10.6.4 while `.agents/version.json` is 10.7.4). Operator option B (2026-11-16): separate BUG; CRP-334 (Specification template currency) is `verified` and stays unchanged.

## 1. Gate 0 Contract

- **Target State**: (1) every scaffolded placeholder document carries `Status: Placeholder` in its header, and the lifecycle refuses `in_progress` -> `verified` (and the Gate 1 presentation of a CRP) while `Implementation_Plan.md` is still a placeholder, and `verified` while `Walkthrough.md` is still a placeholder; (2) the slug is not silently truncated: an existing bundle folder for the same ID is reused, and any shortening is reported in the tool output; (3) `lcm_version` of a new proposal equals `LCM_AI/.agents/version.json`.
- **Exit Criteria**: Pester tests in TestDrive (BUG-336 isolation) for each of the three points; a live registration check is not part of the tests.
- **Explicit Non-Goals**: no rename of existing bundle folders (CRP-330, CRP-339, this BUG keep their truncated names); no change of the Specification template content (CRP-334); no change of other gates.