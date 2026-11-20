# Specification: BUG-376

Module: docs/Proposals/376_BUG-Specification-Header-Status-Not-Synced-With-Lifecy/Specification BUG-376.md  
Purpose: Specification Header Status Not Synced With Lifecycle  
Path: LCM_Inventory/docs/Proposals/376_BUG-Specification-Header-Status-Not-Synced-With-Lifecy/Specification BUG-376.md  
Authors: Claude  
Version: 10.7.4  
Status: Pushed  
Date: 2026-11-19 17:56:58

```yaml
CRP-ID: BUG-376
Title: Specification Header Status Not Synced With Lifecycle
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Claude
Date: 2026-11-19 17:44:11
Status: Pushed
Plan-State: pushed
Progress-State: pushed
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
The lifecycle sync (ProposalSpecificationState) updates the YAML block of a Specification (Status, Plan-State, Progress-State) but not the DOX header line Status:, which keeps the intake value (e.g. BUG-370: header Suggested, YAML In Review). Found by the operator during the Gate 2 review 2026-11-19. Fix: header Status follows the YAML on every sync; one-time alignment of existing bundles.
- Review: this Specification only (Plan and Walkthrough not written yet).

## 2. Gate 0 Contract
### Target State
The DOX header line `Status:` of a bundle Specification always shows the same status as its YAML `Status`: the
lifecycle sync updates both; existing bundles are aligned once.

### Invariants and Exit Criteria
- The Markdown line break of the header line (two trailing spaces) is kept; body lines (also lines starting with
  `Status:` below the fence) are never touched; YAML handling unchanged.
- Old header values are recorded in the Walkthrough before they are replaced (no information lost).
- Exit: a check over all bundle Specifications finds no header/YAML Status mismatch; the lifecycle tests pass.

### Explicit Non-Goals
- Plan and Walkthrough headers (their `Status:` is not lifecycle-driven).
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.
