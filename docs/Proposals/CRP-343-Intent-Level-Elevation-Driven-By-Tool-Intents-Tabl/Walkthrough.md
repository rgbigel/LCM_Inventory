# Walkthrough: CRP-343 - Intent-Level Elevation Driven By Tool Intents Table

Module: docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough.md  
Purpose: Implementation and verification record for CRP-343 (decisions D1-D4, section 7 of the Specification).  
Path: LCM_Inventory/docs/Proposals/CRP-343-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-17 17:00:34

---

## 1. Executive Summary

Implemented by Claude in DOIT (chain A, operator 2026-11-17). The DO daemon (`DoT/do.exe`, Go 10.2.4) now decides elevation per atom from the intent table. It authenticates callers with a per-boot key and starts everything that is not a legal elevated atom with the operator's explorer token (Medium integrity). Rollback copy of the previous binary: `LCM_Inventory/scratch/do-before-crp343.exe`.

## 2. Changes

| Area | Files | Decision |
|:---|:---|:---|
| Caller key, page shim, CORS removal on key-carrying pages | `src/do/auth.go`, `daemon.go` | D2 |
| Port-squatting guard (client sends key only to the genuine `do.exe` listener) | `src/do/serverid.go`, `client.go`; PowerShell: `modules/LcmDoClient.psm1` | D2 |
| Verify-legal-elevation helper: fast path (intents), slow path (caller chain, direct caller tool admin), dry run `GET /api/elevation/verify` | `src/do/elevation.go`, `callerid.go` | D3, D4 |
| Composite commands never elevated (atom confinement) | `src/do/elevation.go` (`isCompositeCommand`) | D4 |
| Non-elevated launch: explorer token + `CreateProcessWithTokenW` for `/execute`, `/open`, `/open_editor`, display rendering | `src/do/elevation.go`, `daemon.go` | D1 |
| Elevation policy + consistency check from `tools.db` (read-only) | `tools/Export-LcmElevationPolicy.py` -> `data/tools/elevation_policy.json` | corollary 1, 2 |
| Mount worker as external atom (unchanged code) | `tools/Invoke-MacriumMountWorker.ps1`; shared helpers moved to `modules/LcmMacriumAtoms.psm1` | corollary 3 |
| Admin dispatcher | `tools/Mount-MacriumLatestBaseline.ps1` 10.2.3 (`-ImagePath` mode) | confirmed invariant |
| BCR: mount via child process of the admin tool; registry write via `Set-LcmMachineRegistry.ps1` atom | `tools/Invoke-MacriumDailyBcrBaseline.ps1` | confirmed invariant |
| Catalog: generator no longer derives `elevated` from `Admin` (preserved, new intents non-elevated); BCR tools `Admin = false`, their 6 intents `elevated = false`; mount intents `elevated = false`; new worker tool (admin) + intent (elevated) | `tools/Update-ToolCatalog.ps1`, `config/tool_intents.json`, `config/tool_catalog.json`, `Sync-LcmToolCatalogDb.ps1 -Action Sync` | admin != elevated |
| Tests | `src/do/auth_test.go` (key, shim, CORS, decision table, composite commands); `tests/MacriumBcrReview.Tests.ps1` (5 assertions read the BCR implementation set; new structure test) | - |

## 3. Verification Evidence (2026-11-17)

- Probe (scratch): `CreateProcessAsUser` with the explorer token fails (privilege not held); the linked token cannot be made primary; `CreateProcessWithTokenW` with the explorer token yields `Medium Mandatory Level`.
- `go vet` 0 findings; `go test` ok; parse gate 0 errors for every changed `.ps1`/`.psm1`; `py_compile` ok.
- Pester `tests/MacriumBcrReview.Tests.ps1`: 15 passed, 0 failed.
- Catalog sync: 353 tools, 673 intents; policy: 82 elevated atoms; mount worker, `Set-LcmMachineRegistry.ps1`, `Dismount-MacriumCurrentBaseline.ps1` are elevated atoms of admin tools; `Invoke-MacriumBcrReview.ps1` / `Invoke-MacriumDailyBcrBaseline.ps1` are not elevated.
- Live daemon after deployment (PID changes on restart; key file `%LOCALAPPDATA%\LCM\do.key` present):
  1. `do.exe "whoami /groups" -sync` -> Medium (before: High for every command).
  2. Dry run, mount atom with key -> elevate (fast path); without key -> not elevated.
  3. Dry run, BCR tool with key -> not elevated.
  4. Browser-style POST (`Origin` set) without key -> 401.
  5. `/hub` page carries the key shim and no `Access-Control-Allow-Origin`.
  6. Composite command naming an atom (`...Set-LcmMachineRegistry.ps1 -Help; whoami /groups`) -> not elevated (found during verification, fixed and redeployed).

## 4. Open (not yet verified or not in this segment)

- Live BCR mount through the new atom: only on the next real new baseline (today's image is mounted; a remount would destroy review markers, RULE-REV-012).
- Operator live test: Control Hub / Tool Explorer buttons (pages now send the key; launched programs run non-elevated unless they are elevated atoms).
- Transition: PowerShell tools that post to the daemon without `LcmDoClient.psm1` run non-elevated; tools that relied on daemon elevation must be migrated (e.g. `Dismount-MacriumCurrentBaseline.ps1` delegation, `Invoke-LcmAction.ps1`). `LCM_DO_REQUIRE_KEY` is not set.
- Policy regeneration after catalog changes is a manual step (`Export-LcmElevationPolicy.py`) until wired into `Sync-LcmToolCatalogDb.ps1`.
- Consistency check: 33 findings (heuristic; `Update-ToolCatalog.ps1` hits likely false) -> input for the temporary cleanup tool; to be based on the tool-call xref table (learned-advice candidate 2026-11-17).
- Section 8 (integrity of the intent table) deferred by the operator.
