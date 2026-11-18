# Walkthrough: CRP-343 - Intent-Level Elevation Driven By Tool Intents Table

Module: docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough CRP-343.md  
Purpose: Implementation and verification record for CRP-343 (decisions D1-D4, section 7 of the Specification).  
Path: LCM_Inventory/docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough CRP-343.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: In Progress  
Date: 2026-11-18 20:59:37

---

## 1. Executive Summary

Implemented by Claude in DOIT (chain A, operator 2026-11-17). The DO daemon (`DoT/do.exe`, Go 10.2.4) now decides elevation per atom from the intent table. It authenticates callers with a per-boot key and starts everything that is not a legal elevated atom with the operator's explorer token (Medium integrity). Rollback copy of the previous binary: `LCM_Inventory/scratch/do-before-crp343.exe`.

## 2. Changes (segment 1)

| No | Area                              | Files                                               | Decision      |
|:--:|:----------------------------------|:----------------------------------------------------|:--------------|
| 1  | Caller key, page shim, no CORS    | `src/do/auth.go`, `daemon.go`                       | D2            |
| 2  | Port-squatting guard              | `src/do/serverid.go`, `client.go`, `LcmDoClient.psm1` | D2          |
| 3  | Elevation decision, dry run       | `src/do/elevation.go`, `callerid.go`                | D3, D4        |
| 4  | Composite commands not elevated   | `src/do/elevation.go`                               | D4            |
| 5  | Non-elevated launch               | `src/do/elevation.go`, `daemon.go`                  | D1            |
| 6  | Policy and consistency check      | `tools/Export-LcmElevationPolicy.py`                | corollary 1-2 |
| 7  | Mount worker as atom              | `Invoke-MacriumMountWorker.ps1`, `LcmMacriumAtoms.psm1` | corollary 3 |
| 8  | Admin dispatcher                  | `Mount-MacriumLatestBaseline.ps1` 10.2.3            | invariant     |
| 9  | BCR mount and registry atoms      | `Invoke-MacriumDailyBcrBaseline.ps1`                | invariant     |
| 10 | Catalog: admin != elevated        | `Update-ToolCatalog.ps1`, `config/*.json`, sync     | T1            |
| 11 | Tests                             | `src/do/auth_test.go`, `MacriumBcrReview.Tests.ps1` | -             |

Details:
- 1: per-boot key `%LOCALAPPDATA%\LCM\do.key`, sent as `X-LCM-Key`; served pages get the key injected and no `Access-Control-Allow-Origin`.
- 2: `do.exe` sends the key only to a listener that is the same binary.
- 3: fast path = intent table; slow path = caller chain and the direct caller tool's admin value; `GET /api/elevation/verify` returns the decision without executing.
- 5: explorer token + `CreateProcessWithTokenW` for `/execute`, `/open`, `/open_editor`, display rendering.
- 10: the generator no longer derives `elevated` from `Admin`; BCR tools `Admin = false`, their 6 intents `elevated = false`; mount intents `elevated = false`; new worker tool (admin) with an elevated intent.
- 11: `auth_test.go` covers key, shim, CORS, decision table, composite commands; `MacriumBcrReview.Tests.ps1` 5 assertions on the BCR implementation set plus one structure test.
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

## 4. Results After Segment 1

| Date       | Check                                          | Result                                                      |
|:-----------|:-----------------------------------------------|:------------------------------------------------------------|
| 2026-11-17 | Operator live test, Control Hub / Tool Explorer | buttons work; defects found -> BUG-352 (completed)          |
| 2026-11-18 | BCR mount through the elevated worker atom     | F: remounted, browse-dialog atom SUCCESS (CRP-344 evidence) |
| 2026-11-18 | Beyond Compare launched by BCR                  | non-elevated, one window (PID 40376)                        |

- Items still open moved to the Specification (T3 key transition, T4 cross-reference basis) and the Implementation Plan (steps 3 and 7), 2026-11-18 (operator: open items are specified, not walked through).