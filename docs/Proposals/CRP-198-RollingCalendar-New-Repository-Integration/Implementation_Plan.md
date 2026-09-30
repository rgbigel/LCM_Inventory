# Implementation Plan — CRP-198: RollingCalendar New Repository Integration

Module: Workspace_Inventory/docs/Proposals/CRP-198-RollingCalendar-New-Repository-Integration/Implementation_Plan.md
Purpose: Technical file breakdown and execution plan for CRP-198.
Path: Workspace_Inventory/docs/Proposals/CRP-198-RollingCalendar-New-Repository-Integration/Implementation_Plan.md
Authors: rgbig, Workspace_AI Governance
Version: 8.1.1
Status: Verification
Date: 2026-09-30

---

## Execution Steps

| Step | Action | Target |
|:---|:---|:---|
| 1 | `git init D:\Git_Repositories\RollingCalendar` | New repo |
| 2 | Create `.agents\rules` junction → `Workspace_AI\.agents\rules` | Governance wiring |
| 3 | Write corrected `Invoke-RollingCalendar.ps1` | Main script |
| 4 | Write `.gitignore` | VCS exclusion |
| 5 | Write `README.md` | Navigation index |
| 6 | Write `docs\Architecture.md` | Tripartite |
| 7 | Write `docs\Requirements.md` | Tripartite |
| 8 | Write `docs\Implementation.md` | Tripartite |
| 9 | Write `install\Installation.md` | 7-phase runbook |
| 10 | Register CRP-198 in `proposals.json` | Ledger |
| 11 | Scaffold bundle directory in `Workspace_Inventory` | CM archive |
| 12 | Initial git commit in `RollingCalendar` | VCS baseline |
| 13 | Repair PowerShell script and function contracts | Quality-gate remediation |
| 14 | Add and run focused Pester structural tests | Verification before review |
| 15 | Dispatch automated BCompare review | Next review gate |
| 16 | Implement time, output, display, and Edge-diagnostic interface changes | Completed |
| 17 | Run focused regression tests and dispatch a refreshed review | Completed: 7 tests passed; five intended files staged for review |

---

## Files Created

| File | Repo |
|:---|:---|
| `Invoke-RollingCalendar.ps1` | `RollingCalendar` |
| `.gitignore` | `RollingCalendar` |
| `README.md` | `RollingCalendar` |
| `docs/Architecture.md` | `RollingCalendar` |
| `docs/Requirements.md` | `RollingCalendar` |
| `docs/Implementation.md` | `RollingCalendar` |
| `install/Installation.md` | `RollingCalendar` |
| `docs/Proposals/CRP-198-.../Specification.md` | `Workspace_Inventory` |
| `docs/Proposals/CRP-198-.../Implementation_Plan.md` | `Workspace_Inventory` |
| `docs/Proposals/CRP-198-.../Walkthrough.md` | `Workspace_Inventory` |
