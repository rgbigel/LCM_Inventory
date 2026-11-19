# Walkthrough: CRP-332 - Workspace CRLF Line-Ending Enforcement

Module: docs/Proposals/332_CRP-Workspace-CRLF-Line-Ending-Enforcement/Walkthrough CRP-332.md  
Purpose: Verification evidence for CRP-332 (Claude, DOIT) before Gate 2.  
Path: LCM_Inventory/docs/Proposals/332_CRP-Workspace-CRLF-Line-Ending-Enforcement/Walkthrough CRP-332.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4  
Status: Verified by automated pre-tests (Gate 2 pending)  
Date: 2026-11-15 15:56:40

---

## 1. Lifecycle

- 2026-11-15 15:41:57 registered (`suggested`) by Claude; 2026-11-15 operator "ACCEPT 332, DOIT" -> `in_progress` (DOIT) via `Invoke-ProposalAction.ps1 -Action do`.

## 2. Verification Evidence (2026-11-15)

| Check | Result |
|:---|:---|
| `Parser::ParseFile` on all new/changed scripts (atoms, tests, tool, `Submit-ReviewResult.ps1`, hook, `ConvertTo-LcmTranscript.ps1`) | 0 errors |
| `settings.json` `ConvertFrom-Json` | valid |
| Pester `LcmLineEndingAtoms.Tests.ps1` + `LcmElevatedDaemon.Tests.ps1` (covers `Submit-ReviewResult.ps1 -Help`) | 23 passed, 0 failed |
| Dry run before conversion | 2,332 governed files scanned; 418 with lone LF in the five LCM_* repos, 1 in the root |
| Apply | 418 + 1 converted, 0 failed (log `data/logs/lcm/Repair-LcmLineEndings-20261115_155550.log` and `..._155502.log`); 10 `*.cmd` trampolines among them |
| Recheck | 0 files with lone LF; 0 failed |
| `.gitattributes` | `git check-attr eol` = `crlf` in LCM_Shared, LCM_Supervision, LCM_Tools |
| Claude hook, simulated event via the root junction path | LF test file converted to CRLF; malformed input exits 0 (never blocks) |

## 3. Defects Found and Fixed During Implementation

- Hook and `ConvertTo-LcmTranscript.ps1` resolved the workspace root three levels up; through the root `.claude` junction that ends at `D:\`. Fixed: search upward for the folder containing `LCM_Inventory`.
- `Repair-LcmLineEndings.ps1 -Path a,b` via `pwsh -File` arrives as one string; fixed by splitting on commas.

## 4. Caveats and Open Points

- The completion-time step in `Submit-ReviewResult.ps1` is exercised for real only by the next COMPLETE (e.g. of this CRP): Gate 2 live test.
- `*.go` and `*.sh` are excluded from conversion (gofmt rewrites to LF; shell scripts need LF). Operator decision 2026-11-15: no change in this area until more evidence exists (a mixed-rule case).
- The Claude hook takes effect for new Claude sessions (settings are read at session start).
- Files with BOM-less non-UTF-8 encodings are converted byte-wise, which is safe for all ASCII-compatible encodings; UTF-16/32 files are skipped.
- BCR may list the 419 converted files if its `_LCM` profile compares line endings; operator: CRLF corrections are not review-relevant.

## 5. Gate 2 Review Guide (ranked)

1. `Submit-ReviewResult.ps1`: the new block before `if ($StagedOnly)`, header.
2. `LcmLineEndingAtoms.psm1`: `ConvertTo-LcmCrlfBytes`, `Repair-LcmLineEnding`.
3. `Repair-LcmLineEndings.ps1`.
4. Adapter: `.claude/hooks/Invoke-ClaudeCrlfHook.ps1`, `.claude/settings.json`.
5. Everything else is line-ending conversion only.
