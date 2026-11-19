# Specification: BUG-375

Module: docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Specification BUG-375.md  
Purpose: Tests Write Intent Statistics Into The Live Store  
Path: LCM_Inventory/docs/Proposals/375_BUG-Tests-Write-Intent-Statistics-Into-The-Live-Store/Specification BUG-375.md  
Authors: Claude  
Version: 10.7.4  
Status: Completed  
Date: 2026-11-19 17:54:33

```yaml
CRP-ID: BUG-375
Title: Tests Write Intent Statistics Into The Live Store
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 17:29:17
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
tests/ToolIntentMetrics.Tests.ps1 (and a second test) call Update-LcmToolIntentCall (modules/LcmToolCatalog.psm1:943), which writes call_count / last_called_at into the live config/tool_intents.json: every readiness gate run changes live statistics. Found by the CRP-358 parallel session 2026-11-19. Tests must use an isolated store.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
No unit test writes a live store: intent statistics, catalog, ledger and database files are written only into isolated
copies (TestDrive) during tests; the statistics writer takes its store from a redirect (LCM_TOOL_INTENTS_PATH) or,
by default, relative to its module.

### Invariants and Exit Criteria
- The tests keep testing the same behaviour (metrics update, millisecond timestamps, carry-over, CLI rendering,
  ledger sync / verify / query / hydrate).
- Exit: a probe that hashes every live store before and after each test file shows no change for all test files that
  call a store writer; the tests pass.

### Explicit Non-Goals
- Resetting the statistics already polluted by earlier gate runs (operator decision, see the open item below).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## Evidence and Open Item (2026-11-19)

- The 7 intent rows whose JSON statistics differ from `tools.db` (`test-lcmrulehealth`, `submit-reviewresult`, `show-toolintents` and aliases) carry the times of the readiness gate runs of 2026-11-19 (12:36-12:37, 16:02-16:03): test calls, not real ones.
- Open: the existing statistics are polluted by earlier gate runs and cannot be separated afterwards; operator decision with the fix: reset them once, or keep them and count correctly from then on.
