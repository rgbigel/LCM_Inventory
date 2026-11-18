# Change Request Proposal: CRP-300

```yaml
CRP-ID: CRP-300
Title: Commit current LCM 10.0.0 version alignment in non-LCM repositories
Scope: AuthorizeMasterUser, BackgroundModifier, BGMSAMVInv, BootEntryManager, VolumeInventory
Author: rgbig
Date: 2026-10-20
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Priority: High
```

---

## 1. Executive Summary & Intent

Complete the governed local commits for the already-implemented and operator-reviewed current-version alignment in exactly five non-LCM repositories. The operator accepted the full-workspace Beyond Compare review on 2026-10-20. Each repository must receive its own review receipt and local commit through `Submit-ReviewResult.ps1`. This proposal does not authorize a push.

## 2. Gate 0 Contract

### Target State

All current item-version declarations below `10.0.0` in the five named repositories are `10.0.0`, and the reviewed changes are committed locally in each repository with formal RR review receipts.

### Invariants and Exit Criteria

- Scope is limited to `AuthorizeMasterUser`, `BackgroundModifier`, `BGMSAMVInv`, `BootEntryManager`, and `VolumeInventory`.
- Each diff contains only current version declarations changed to `10.0.0`; no functional code changes are included.
- Historical changelog entries, terminal BUG records, release tags, and all other history remain unchanged.
- Every repository passes its applicable readiness/syntax gate before its commit.
- Each repository receives a separate formal review receipt and local commit.
- No push or unrelated repository commit is performed.

### Explicit Non-Goals

- No changes to any `LCM_*` repository, including `LCM_Inventory`, `LCM_AI`, `LCM_Shared`, or `LCM_Tools`.
- No behavior, documentation-content, test, configuration, or application changes beyond current-version metadata.
- No normalization or rewriting of historical version declarations.
- No remote push.

## 3. Technical Requirements & Invariants

- Preserve the exact five-repository scope and current-version-only change set.
- Preserve all historical version values and existing line endings.
- Use formal repository-specific RR receipts and commits after the accepted full-workspace BCR.

## 4. Verification and Review

- Inspect the complete per-repository diff before each RR submission.
- Run repository readiness/syntax validation for all five repositories.
- Confirm each commit contains only the expected version declaration changes and receives an RR receipt.
- Confirm all five repositories are clean afterward; leave LCM-prefixed repositories untouched by this proposal.
