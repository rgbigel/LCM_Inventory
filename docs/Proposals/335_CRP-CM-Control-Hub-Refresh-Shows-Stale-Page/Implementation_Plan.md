# Implementation Plan: CRP-335 - CM Control Hub Refresh Shows Stale Page

Module: docs/Proposals/335_CRP-CM-Control-Hub-Refresh-Shows-Stale-Page/Implementation_Plan.md  
Purpose: Root cause, change and Gate 0 traceability for CRP-335 (Claude, DOIT).  
Path: LCM_Inventory/docs/Proposals/335_CRP-CM-Control-Hub-Refresh-Shows-Stale-Page/Implementation_Plan.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4  
Status: Implemented (DOIT, awaiting Gate 2 incl. daemon redeploy)  
Date: 2026-11-15 16:49:09

---

## 1. Root Cause

The `do` daemon (`src/do/daemon.go`, listener on 9876) answers `POST /displays/refresh/<id>` with `state: Current` and a revision derived from the existing artifact's timestamp; it never re-renders. The re-render logic of the PowerShell coordinator (`modules/LcmDisplayCoordinator.psm1`, fingerprints + `Invoke-LcmDisplayRender.ps1`) was not ported when the Go daemon took over port 9876. The hub front end (`assets/CM_CONTROL_HUB.html` Refresh -> `lcm-display-freshness.js` -> `POST /displays/refresh/hub`) is correct. Last coordinator render log: 2026-11-13 16:22.

## 2. Change

| Change in `LCM_Inventory/src/do/daemon.go` (10.2.1 -> 10.2.2) | Gate 0 clause |
|:---|:---|
| `POST /displays/refresh/<id>` runs `Invoke-LcmDisplayRender.ps1 -DisplayId <id>` synchronously (120 s timeout, serialized) before computing the revision; failure returns `state: Failed` with the log path | Target state / exit criterion |
| `GET` on the refresh route returns 405 (as the PowerShell coordinator did) | Consistency |
| Ids the renderer does not support (`tool_intents`, `intents`) keep the previous behaviour | Non-goal: no redesign |
| Header VERSION / LAST MODIFIED / CHANGE LOG (GO-1) | RULE-DOC-011 |

## 3. Deployment (needed for the Gate 2 live test)

The running daemon (elevated scheduled task) still uses the old binary. Staged build: `LCM_Inventory/scratch/do-crp335.exe` (SHA-256 prefix 34851938D63BC24E). Replace the daemon binary and restart the daemon task (elevated).