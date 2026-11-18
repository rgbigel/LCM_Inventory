# Implementation Plan: CRP-324

## Strategy Mapping Relational Engine, Referential Integrity Validation, and ShowStrategies UI

### Phase 1: Database Schema & Projection Engine
- [ ] Extend `sync_proposals_db.py` and `Sync-LcmProposalsDb.ps1`:
  - Add `strategies` and `strategy_crps` table DDL.
  - Implement bidirectional sync for `data/proposals/strategies.json` -> SQLite `proposals.db` + `strategies.sql`.
- [ ] Create initial seed `strategies.json` containing `STRAT-001` through `STRAT-005`.

### Phase 2: Referential Integrity Validator
- [ ] Author [`LCM_Inventory/tools/Test-LcmStrategyConsistency.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Test-LcmStrategyConsistency.ps1):
  - Checks every Strategy's member CRPs.
  - Verifies presence in `proposals.db`.
  - Flags violations if any member CRP is in `rejected`, `superseded`, or `cancelled` state.
- [ ] Add Pester unit tests in `LCM_Inventory/tests/Test-LcmStrategyConsistency.Tests.ps1`.

### Phase 3: `ShowStrategies` Dashboard & `ShowCM` Integration
- [ ] Author `LCM_Inventory/ui/ShowStrategies.html`:
  - Renders strategic overview cards with progress bars and interactive CRP badges.
  - Visual alert chips for any consistency warnings.
- [ ] Author launcher script [`LCM_Inventory/tools/Show-Strategies.ps1`](file:///D:/Git_Repositories/LCM_Inventory/tools/Show-Strategies.ps1) and trampoline `LCM_Inventory/DoT/ShowStrategies.cmd`.
- [ ] Update `CM_CONTROL_HUB.html`:
  - Add `Strategies` button in Topbar / Status Rail to launch or navigate to `ShowStrategies`.
  - Add Strategy badge to Proposal Details inspector.

### Phase 4: Verification & Readiness
- [ ] Execute `Sync-LcmProposalsDb.ps1 -Action Sync`.
- [ ] Run `Test-LcmStrategyConsistency.ps1` and verify all seed strategies pass.
- [ ] Verify 6/6 General Readiness gates pass across all governed repositories.

