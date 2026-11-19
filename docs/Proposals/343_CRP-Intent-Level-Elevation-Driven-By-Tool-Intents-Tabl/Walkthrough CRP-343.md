# Walkthrough: CRP-343 - Intent-Level Elevation Driven By Tool Intents Table

Module: docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough CRP-343.md  
Purpose: Implementation and verification record for CRP-343 (decisions D1-D4, section 7 of the Specification).  
Path: LCM_Inventory/docs/Proposals/343_CRP-Intent-Level-Elevation-Driven-By-Tool-Intents-Tabl/Walkthrough CRP-343.md  
Authors: Rolf, Claude  
Version: 10.7.4  
Status: In Progress  
Date: 2026-11-19 10:14:39

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

## 5. Segment 2, core (2026-11-18 23:44:31)

- Deviation: no separate migration tool; the catalog generator converts legacy booleans (true -> 3, false -> 1) and its override table now holds the levels; new tools land at 0 (TBD) unless admin code is found.
- Deviation: `Invoke-MacriumBcrReview.ps1` is `granted` (1), not `controlled`: it calls no elevated atom itself (Specification: lists follow the real calls).
- Found on the way: a one-atom list was unrolled to a string by PowerShell and split into letters by the sync; fixed in both places. One lone CR in the generator header normalized.
- Order kept: readers first, then generator and sync, then daemon and policy in one deployment.

| Check                                              | Result                                               |
|:---------------------------------------------------|:-----------------------------------------------------|
| tools.db levels after sync                         | 1 = 267, 2 = 2, 3 = 90; 3 atom permissions           |
| `go vet`, `go test` (incl. `TestCallerDecision`, 9 rows) | clean, ok                                 |
| `ToolPermissionLevels.Tests.ps1` (new)              | 4/4                                                  |
| Related Pester files (10)                          | 90 passed, 2 failed in FailureModeAnalysis (tool not touched) |
| Live dry run: mount / registry atom with key       | elevated (fast path)                                 |
| Live dry run: same without key                     | not elevated                                         |
| Live dry run: BCR tool, plain command              | not elevated                                         |
| Live: DO command level                             | Medium                                               |
| Tool Explorer screenshot                           | badges `granted` / `admin`; admin card 90           |
| Running Macrium backup during the redeploy         | unaffected                                           |

## 6. Consistency check: catalog data false positives (2026-11-19 09:16:39)

- Operator option C (2026-11-19): fix only the scanner false positives now; the other conflicts wait for step 7.
- Cause: `CALL_MARKERS` matched `-file` inside the catalog seed strings `Example = 'pwsh -File ...'` of `Update-ToolCatalog.ps1` (13 hits), against the documented intent that catalog data is ignored.
- Change: `Export-LcmElevationPolicy.py` skips property assignments of a string literal (`DATA_LITERAL`, `Name = '...'` / `Name = "..."`); `$var = join-path ...` and `& '...'` still count.
- Found on the way: the first pattern `["'']` was two adjacent Python literals (class held only `"`); corrected to `[\x27"]`.

| Check | Result |
|:---|:---|
| `py_compile`, `flake8` (E9,F63,F7,F82,F401,F541,F841) | clean |
| Pattern probe: `example = 'pwsh -file x'` / `$dispatcher = join-path a b` / `& 'x.ps1'` | skipped / counted / counted |
| `--check` before / after | 31 / 18 violations; the 13 removed are exactly the `Update-ToolCatalog.ps1` hits |
| `elevation_policy.json` regenerated | 18 violations |

## 7. Consistency check: operator decisions on the 5 individual cases (2026-11-19 09:23:49)

- Operator 2026-11-19: cases 3-5 option C, case 16 option B, case 18 option A.
- Cases 3-5: `AdminShell.ps1` is `controlled` (2) with the list `disable`, `enable`, `uninstall` (override table in `Update-ToolCatalog.ps1`). Observed on the way, not changed: `AdminShell.ps1`, `Disable.ps1`, `Enable.ps1`, `Uninstall.ps1`, `Verifyer.ps1` carry the header `Path: .\Install` and the menu points to `Source\BootIdentity.ps1`, `BackgroundRenderer.ps1`, `Setup.ps1` (absent); they look like a BackgroundModifier installer copy.
- Case 16: `Test-ExternalTools.ps1` run in a non-elevated shell: all 14 checks OK, exit 0; intents `test-externaltools` and `testexternaltools` set to `elevated: false` in `config/tool_intents.json` (preserved by the generator). The tool keeps level 3 (admin users only); that is no conflict.
- Case 18: `Export-LcmElevationPolicy.py` skips HTML markup lines (`MARKUP_LINE`, `^<[a-z!/]`); the bridge quick-action route belongs to the BUG-348 daemon items.
- Found on the way: the first intent edit stopped at the nested `"parameters": {}` and wrote nothing; redone with an exact two-occurrence replacement.

| Check | Result |
|:---|:---|
| `ParseInput` `Update-ToolCatalog.ps1`; `py_compile`, `flake8` scanner; `ConvertFrom-Json` intents | 0 errors; clean; OK |
| `--check` after the markup rule (old tools.db) | 17 |
| `Update-ToolCatalog.ps1 -Silent`, `Sync-LcmToolCatalogDb.ps1` | exit 0; 359 tools, 690 intents, `tools.sql` dumped |
| tools.db: `AdminShell.ps1` level / `Test-ExternalTools` elevated intents | 2 / none |
| `elevation_policy.json` regenerated | 82 elevated atoms (83 before); 13 violations = 9 `Invoke-InteractiveDesktop.ps1` callers + 4 daemon lifecycle callers |

## 8. LCM_Tools links removed from LCM_Inventory\tools (2026-11-19 09:44:55)

- Operator 2026-11-19: `AdminShell.ps1` lives in `LCM_Tools`; the link in `LCM_Inventory\tools` is a left-over of the `\tools` ingestion. Remove the links to `LCM_Tools` and the catalog duplication.
- Test before (operator suggestion): a probe tool placed only in `LCM_Tools\tools` (no link) was catalogued under its own path, got `Cmd` and `DoT` trampolines that ran it (exit 0), and was removed cleanly by the next generator run (1262 files compared; only the `Updated` stamps of `tool_intents.json` and `docs/README.md` differed). Trampoline maintenance needs no links.
- Removed: the 63 symbolic links in `LCM_Inventory\tools` that target `LCM_Tools\tools` (git mode 120000; reparse check, `File.Delete`, every target verified intact). Kept: 7 links into `HaSSD06`, 3 into `LCM_Supervision` (not in the order).
- Callers that relied on a link: `Update-Gemini.ps1` (snapshot step at every PUSH) and the deprecated stub `Export-LcmKnowledgeBase.ps1` had wrong fallbacks (`<root>\tools\`, `LCM_Tools\` without `tools`); both now fall back to `LCM_Tools\tools\Sync-LCMResearchSnapshot.ps1`.
- Cases 3-5 decision (level 2, list `disable`, `enable`, `uninstall`) now applies to `LCM_Tools\tools\AdminShell.ps1` (override keyed by name).
- Not changed: 4 names keep two rows because `SystemConfiguration\Source` holds a different file of the same name (`GoAdm.ps1`, `search certificate stores for private key container Guids.ps1`, `Set-MachineWideExecutionPolicy.ps1`, `Test-PowerShellHklmState.ps1`); these are General_Tools draft matters (section A). Cleanup candidate `tools\RunShell.ps1` in `Invoke-LcmMajorCleanup.ps1` is now absent on disk.

| Check | Result |
|:---|:---|
| `ParseFile` `Update-Gemini.ps1`, `Export-LcmKnowledgeBase.ps1`; fallback paths resolve | 0 errors; yes |
| `Update-ToolCatalog.ps1 -Silent`, `Sync-LcmToolCatalogDb.ps1` | exit 0; 359 tools, 690 intents |
| tools.db rows on a removed link path / on `LCM_Tools\tools` for the 63 | 0 / 63 |
| `Cmd` trampolines on a removed link path / on `LCM_Tools\tools` | 0 / 63 |
| `elevation_policy.json` | 82 elevated atoms, 13 violations (unchanged) |
| `ToolPermissionLevels.Tests.ps1` | 4/4 |

## 9. HaSSD06 and LCM_Supervision links removed (2026-11-19 09:52:29)

- Operator 2026-11-19: HaSSD06 and LCM_Supervision are governed subsystems outside LCM, like LCM_Tools; their links in `LCM_Inventory\tools` go as well.
- Removed: 10 symbolic links (7 into `HaSSD06`, 3 into `LCM_Supervision\tools`; git mode 120000; targets intact). `LCM_Inventory\tools` holds no links any more.
- No dependency on the link paths: MCP configs (`.mcp.json`, `*\.agents\mcp_config.json`) use `d:/Git_Repositories/HaSSD06/mcp_ha_readonly.py`; no scheduled task names them; code refers to the physical paths.
- Admin decision check: no level, list or elevated atom is attached to a link path any more; the only `LCM_Inventory\tools` override key is `Invoke-LcmDo.ps1` (own tool). The two remaining subsystem violations (`HaSSD06_Inventory` Build/Show viewers -> `Invoke-InteractiveDesktop.ps1`) belong to step 7.
- Not changed (not links): 11 physical copies in `LCM_Inventory\tools` identical to `LCM_Tools\tools` files, catalogued twice; 17 same-named but different files vs `HaSSD06` / `HaSSD06_Inventory` / `LCM_Supervision`. Reported to the operator.

| Check | Result |
|:---|:---|
| `Update-ToolCatalog.ps1 -Silent`, `Sync-LcmToolCatalogDb.ps1` | exit 0; 359 tools, 690 intents |
| tools.db rows for the 10 on a link path / on the physical path | 0 / 10 (admin 1 each) |
| `Cmd` trampolines for the 10 | all resolve to the physical path; 0 stale |
| Supervision tools `-h`; HaSSD06 scripts `py_compile` | exit 0 (3/3); 0 (7/7) |
| `elevation_policy.json` | 82 elevated atoms, 13 violations (unchanged) |

## 10. Ingestion copies in LCM_Inventory\tools (2026-11-19 10:00:41)

- Operator 2026-11-19, choice C for the 11 copies identical to `LCM_Tools\tools` files: deleted (git tracked; originals verified intact; no caller on the `LCM_Inventory` path, `Invoke-LcmDo.ps1:40` is a help example resolved by name). Catalog 359 -> 348 tools, 690 -> 684 intents, 82 -> 81 elevated atoms, 0 stale trampolines, 13 violations.
- Correction: the "General_Tools" draft (`scratch/CRP-draft-General_Tools-Subsystem/`) was written by Claude on 2026-11-16 from the operator remark on the LCM_ prefix; never registered, Gate 0 never presented; no operator decision exists under that name.
- The 15 other same-named files (HaSSD06 / HaSSD06_Inventory) are byte-identical in content to their subsystem originals; only line endings differ (inventory copies CRLF, originals LF since CRP-332). Not name collisions: stale ingestion copies.
- `Test-RepoReadiness.ps1` is a per-repository convention (11 versions, called as `<repo>\tools\Test-RepoReadiness.ps1` by `Show-LCM_Readiness.ps1` and `Invoke-LcmStageTwoFallback.ps1`). The `LCM_Inventory` version is content-identical to `HaSSD06\tools\Test-RepoReadiness.ps1` (labels and gates for HaSSD06, root = `LCM_Inventory`): LCM_Inventory has no readiness gate of its own. Reported; not changed.
- `asus-debloater`: three implementations of one function: `LCM_Tools\tools\asus-debloater.ps1` (234 lines, no header), `SystemConfiguration\Source\asus-debloater.ps1` (v1.1.0, header path `D:\OneDrive\cmd\@Repair\`), `SystemConfiguration\Source\Invoke-AsusDebloater.ps1` (287 lines, governed header, self-elevating). The catalog labels the SystemConfiguration rows subsystem `LCM_Tools`. Reported; not changed.

## 11. Operator choices 1A / 2A / 3A (2026-11-19 10:14:39)

- 1A: the 15 line-ending copies deleted; in the same class found and deleted: `invoke_ha_backup.py`, `invoke_ha_core_update.py`, `Register-BleSupervisionTask.ps1` (twins in `HaSSD06\tools`; scheduled task `HaSSD06_BLE_Supervision` runs a `HaSSD06\scratch` script) and `Show-HaAuthDialog.ps1` (twin in `HaSSD06\tools\subsystem`; macro `ShowHaAuthDialog` now resolves to it as `macro-definitions.md` states). No caller used the `LCM_Inventory` paths. Catalog 348 -> 329 tools; violations 13 -> 11 (the two `LCM_Inventory` HA viewer copies).
- 2A: `LCM_Inventory\tools\Test-RepoReadiness.ps1` rewritten as the LCM_Inventory gate (CRP-310 two-step, CRP-152 receipt): general readiness, tripartite docs (`Assert-TripartiteDocumentationCompliance` plus DOX check), CM engine structure, unit tests (skipped under `-MinimalTests`). Found on the way and fixed: `Test-GeneralReadiness.ps1` gate 1 rejected the current layout where `.agents` itself is the junction into `LCM_AI\.agents` (failed for every repository); `Test-TripartiteDocumentation` exists only in the HaSSD06 module.
- 3A: `SystemConfiguration\Source\Invoke-AsusDebloater.ps1` is the kept implementation; `LCM_Tools\tools\asus-debloater.ps1` and `SystemConfiguration\Source\asus-debloater.ps1` are retire candidates (Plan). Cause of the wrong subsystem found and fixed in `Update-ToolCatalog.ps1`: catalog metadata was inherited by file name, so same-named files in different repositories shared Group, ShortName and Aliases (5 launcher name collisions, one launcher overwrote the other). Now inherited by path; a name match counts only for a moved file; a disambiguated short name is checked again (repository prefix, then counter). The inherited Group/Domain/ShortName/Aliases of the 16 affected entries were reset once (backup in the session scratchpad); Admin levels kept (equal within each pair).
- Observed: the full unit test run inside the gate regenerates the catalog and all `DoT` trampolines and writes `proposals.db`, `CM_CONTROL_HUB.html`, `active_session.json`; `proposals.db` content verified equal to the 00:02 dump (336 rows, 18 columns, 0 differing).

| Check | Result |
|:---|:---|
| `ParseFile` `Test-RepoReadiness.ps1`, `Test-GeneralReadiness.ps1`, `Update-ToolCatalog.ps1` | 0 errors |
| `Test-RepoReadiness.ps1 -MinimalTests` (LCM_Inventory) | PASSED 3/4 (unit tests skipped), exit 0 |
| `Test-RepoReadiness.ps1` full | FAILED: 19 of 362 unit test cases fail (incl. the known ControlHubSafety / ProposalSpecificationState / lifecycle cases; Absorb-LcmContextRemark, Link-LcmLearnedAdvice) |
| `Test-GeneralReadiness.ps1` gate 1 on LCM_Tools, LCM_Supervision, HaSSD06 | passed (`.agents` junction) |
| tools.db after rebuild | 329 tools, 679 intents; 0 short-name collisions; SystemConfiguration rows -> SystemConfiguration; each Test-RepoReadiness under its own subsystem |
| `elevation_policy.json` | 85 elevated atoms (+4: the LCM_Tools twins now have their own intents, owning tools level 3), 11 violations |
| `ToolPermissionLevels.Tests.ps1` | 4/4 |
