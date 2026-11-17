# Specification: BUG-336

Module: docs/Proposals/BUG-336-ProposalManager-Tests-Write-Into-Live-Workspace/Specification.md  
Purpose: ProposalManager.Tests.ps1 writes into the live workspace (ledger JSON, SQLite DB, SQL dump, proposal bundles, session registers, App catalog); isolate it completely.  
Path: LCM_Inventory/docs/Proposals/BUG-336-ProposalManager-Tests-Write-Into-Live-Workspace/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Registered (DOIT)  
Date: 2026-11-16 16:08:46

```yaml
Bug-ID: BUG-336
Title: ProposalManager Tests Write Into Live Workspace
Scope: LCM_Inventory
Version: 10.6.4
Affected-Repos: [LCM_Inventory]
Severity: High
Status: Pushed
Root-Cause: The suite backs up and restores the live proposals.json instead of redirecting the store (LCM_PROPOSAL_STORE_PATH); four New-WorkspaceProposal calls and one Sync-LcmAppCatalog call omit -WorkspaceRoot $TestDrive. Store saves trigger Sync-LcmProposalsDb against the live DB; session registers and the App catalog are written next to the live store.
Plan-State: pushed
Progress-State: pushed
```

---

## 0. Registration Note

Found by Claude while verifying CRP-334 (2026-11-15). Operator rule (2026-11-15): blocking problems without a critical design change are one BUG, fixed in DOIT; this BUG blocks CRP-334 verification.

## 1. Gate 0 Contract

- **Target State**: Running `ProposalManager.Tests.ps1` changes no file outside the Pester `TestDrive` and leaves `proposals.json`, `proposals.db`, `proposals.sql`, `docs/Proposals/`, `data/session_state/active_session.json` and `data/catalog/apps.json` byte-identical.
- **Exit Criteria**: hashes of those live files and the list of bundle folders are identical before and after a full run; the suite passes.
- **Explicit Non-Goals**: no change of module behaviour under this BUG (the store override already exists); other test suites are checked only if they show the same pattern (separate BUG if so).

## 2. Evidence of the 2026-11-15 16:33-16:34 Run

- `proposals.db` gained rows 336-339 (parity check: JSON 309, DB 313); `proposals.sql` contained them.
- Bundles `CRP-336-Test-Feature-Proposal`, `CRP-337-Batch-Action-Test`, `CRP-338-Defer-Test`, `CRP-339-Delete-Test` were created in the live `docs/Proposals/`.
- `data/session_state/active_session.json` lost the RULE-ANA-006 registers (`operating_mode`, `active_gate`, `search_radius`, `settled_facts`, `open_hypotheses`, `circuit_breaker`); its App context "Telemetry Streamer / TestRepoSplit" already stems from an earlier test run (2026-11-10).
- `data/catalog/apps.json` was rewritten (timestamp only).

## 3. Cleanup Already Done (2026-11-15)

- The four test bundle folders deleted.
- `Sync-LcmProposalsDb.ps1 -Action Sync` from the clean live JSON; `-Action Verify`: 100 % parity across 309 proposals (JSON, DB, SQL).
- `active_session.json` and `apps.json` restored to their last committed content (the committed `active_session.json` still carries the 2026-11-10 test App context; left as is for the operator).

## 4. Operator Decisions (2026-11-16, baseline review)

- The stale test App context (`Telemetry Streamer` / `TestRepoSplit`, 2026-11-10) in `data/session_state/active_session.json` is deleted: `active_context` set to `null` (the cleared state written by `ProposalManager.psm1`); done 2026-11-16 16:08:46 by Claude.
- No general live-store guard for all test suites now; deferred until a full LCM consistency check.
- Related: `Test-LcmProposalsDb.Tests.ps1` hydrates the live DB; operator rule: test definitions may live in the live DB, test output MUST NOT (it belongs in history). Separate BUG.
