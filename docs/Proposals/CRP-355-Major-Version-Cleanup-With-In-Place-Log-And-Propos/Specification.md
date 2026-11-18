# Specification: CRP-355

Module: docs/Proposals/CRP-355-Major-Version-Cleanup-With-In-Place-Log-And-Propos/Specification.md  
Purpose: Major Version Cleanup With In-Place Log And Proposal Ledger  
Path: LCM_Inventory/docs/Proposals/CRP-355-Major-Version-Cleanup-With-In-Place-Log-And-Propos/Specification.md  
Authors: Rolf  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 15:40:03

```yaml
CRP-ID: CRP-355
Title: Major Version Cleanup With In-Place Log And Proposal Ledger
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 15:40:03
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-18: a manually triggered cleanup with a new design, because earlier partial cleanups left dead code. After two changes of the major version (current M, delete items of M-2 and older), old items are deleted completely in logs and Proposals; what remains is an in-place log and a proposal ledger, the latter listing the completed proposals. Proposals that are held or otherwise unfinished business are kept regardless of their major version. The cleanup is triggered manually. Include suggestions for further deletions at cleanup.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.

## Absorbed Operator Remarks

> we really need to do a cleanup; some of this had been done a long time ago, so it has left dead code. We need a new design.
> What i want cleaned: after two changes to the major version, i want old items to be completely deleted in logs, Proposals, and an in-place log and proposal ledger (the latter listing the completed Proposals). Proposals that are in HELD or "unfinished business" are to be kept regardless of major version number.
> The cleanup will be triggered manually.
> Start a CRP for this, and make suggestions for further deletions at cleanup

(Operator, 2026-11-18. Gate 0 contract to follow from the read-only inventory and design analysis started the same day.)
