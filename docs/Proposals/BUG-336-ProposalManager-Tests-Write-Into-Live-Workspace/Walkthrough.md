# Walkthrough: BUG-336 - ProposalManager Tests Write Into Live Workspace

Module: docs/Proposals/BUG-336-ProposalManager-Tests-Write-Into-Live-Workspace/Walkthrough.md  
Purpose: Verification evidence for BUG-336 before Gate 2.  
Path: LCM_Inventory/docs/Proposals/BUG-336-ProposalManager-Tests-Write-Into-Live-Workspace/Walkthrough.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Verified by automated pre-tests (Gate 2 pending)  
Date: 2026-11-15 16:42:43

---

| Check (2026-11-15) | Result |
|:---|:---|
| Parse (`ProposalManager.psm1`, both test files) | 0 errors |
| Pester `ProposalManager`, `ProposalSpecificationFence`, `Test-LcmProposalsDb`, `LCM_SwitchIntegration` | 39 passed, 0 failed |
| SHA-256 before/after the run: `proposals.json`, `proposals.sql`, `strategies.json`, `active_session.json`, `apps.json`, bundle folder list | unchanged |
| Same per suite for `proposals.db` | unchanged for ProposalManager, Fence, SwitchIntegration |
| `Sync-LcmProposalsDb.ps1 -Action Verify` | 100 % parity, 310 proposals |

Observation (not changed, design question for the operator): `Test-LcmProposalsDb.Tests.ps1` intentionally runs `Hydrate` and `Verify` against the live DB; content stays identical while the `.db` bytes change. If live-ledger tests are unwanted, that is a separate decision.

Cleanup of the polluting run is recorded in Specification section 3. The committed `active_session.json` still carries the 2026-11-10 test App context "Telemetry Streamer / TestRepoSplit"; left for the operator.

Gate 2 review: the two test files (setup/teardown and the five `-WorkspaceRoot` additions) and the sync guard in `Set-ProposalStore`.