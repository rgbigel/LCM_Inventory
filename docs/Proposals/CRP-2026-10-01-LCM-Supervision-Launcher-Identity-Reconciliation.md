# CRP: LCM_Supervision Launcher Identity Reconciliation

Module: docs/Proposals/CRP-2026-10-01-LCM-Supervision-Launcher-Identity-Reconciliation.md  
Purpose: Suggested correction proposal for the supervision launcher filename and self-reported invocation.  
Path: D:\Git_Repositories\LCM_Inventory\docs\Proposals\CRP-2026-10-01-LCM-Supervision-Launcher-Identity-Reconciliation.md  
Authors: LCM documentation reconciliation  
Version: 1.0.0  
Status: Suggested  
Date: 2026-10-01  

---

## Scope

Repository: `LCM_Supervision`  
State: `suggested`  
Progress state: `undecided`

## Evidence

The physical launcher is `LCM_Supervision/tools/Show-Supervision.ps1`, while
its comment-based help and displayed usage identify
`tools/Show-SupervisionHub.ps1`. No file with that name exists in the current
repository root listing.

## Recommended Correction

Choose one stable public launcher name. Either rename the script and update
callers, or update the script's examples, help banner, and documentation to
use `Show-Supervision.ps1`. Preserve compatibility only if an explicitly
implemented wrapper is required.

## Acceptance Evidence

Run the selected launcher with `-Help` and verify that its displayed invocation
matches the physical entry point and README quick-start command.
