# Specification: CRP-335

Module: docs/Proposals/CRP-335-CM-Control-Hub-Refresh-Shows-Stale-Page/Specification.md  
Purpose: Record that the CM Control Hub (ShowCM) can show a stale page after ledger changes; observation only, no code analysis yet (operator 2026-11-15).  
Path: LCM_Inventory/docs/Proposals/CRP-335-CM-Control-Hub-Refresh-Shows-Stale-Page/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Suggested (registered)  
Date: 2026-11-15 16:29:38

```yaml
CRP-ID: CRP-335
Title: CM Control Hub Refresh Shows Stale Page
Scope: LCM_Inventory
Target Scope: LCM_Inventory/tools/Show-LcmControl.ps1 and the hub front end (refresh path)
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_Inventory]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-15 16:29:38
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 4
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude (WORKPLAN D-29). The operator classified the behaviour as an error, not severe, and considers code analysis premature because a different path for the front end may be followed. Registered as CRP (not BUG) so no DOIT is triggered.

## 1. Gate 0 Contract (draft, to be confirmed)

- **Target State**: After any ledger change, the hub refresh shows the current ledger state.
- **Binding Principle**: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity."
- **Exit Criteria**: a proposal registered or transitioned through the governed tools appears with its current state after one press of the hub refresh, without running ShowCM again.
- **Explicit Non-Goals**: no front-end redesign under this CRP; may be superseded by the operator's alternative front-end path.

## 2. Observations (2026-11-15)

- CRP-332 (15:41:57), CRP-333 and CRP-334 (15:45) were in `proposals.db` and `proposals.json` (last write 15:57:32).
- `LCM_Inventory/data/artifacts/CM_CONTROL_HUB.html` was last rendered at 15:20:41 and did not contain CRP-333; the operator's refresh in the hub did not change it, and no ShowCM render was logged after 15:20.
- The active-horizon filter in `Show-LcmControl.ps1` (lines 264-271) shows all non-terminal items, so the filter is not the cause.
- Running `Show-LcmControl.ps1` again at 16:29:38 rendered a page containing CRP-332..334.
- Operator: Antigravity occasionally does not rebuild the HTML automatically; doubt that the front-end refresh button forces a rebuild.
- Side observation: the ShowCM run logged `Invoke-InteractiveDesktop-20261115_162938.log`, although RULE-ELEV-006 lists `Invoke-InteractiveDesktop.ps1` as retired.
