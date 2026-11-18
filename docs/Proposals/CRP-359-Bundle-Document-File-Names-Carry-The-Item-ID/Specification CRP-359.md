# Specification: CRP-359

Module: docs/Proposals/CRP-359-Bundle-Document-File-Names-Carry-The-Item-ID/Specification CRP-359.md  
Purpose: Bundle Document File Names Carry The Item ID  
Path: LCM_Inventory/docs/Proposals/CRP-359-Bundle-Document-File-Names-Carry-The-Item-ID/Specification CRP-359.md  
Authors: Rolf, Claude  
Version: 10.7.4
Status: Suggested  
Date: 2026-11-18 16:11:42

```yaml
CRP-ID: CRP-359
Title: Bundle Document File Names Carry The Item ID
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf
Date: 2026-11-18 16:11:42
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator 2026-11-18 after the CRP-354 live test: "show crp button works, but shows a design problem: the documents opened are not easily identified in the tabs headers! We need to append the CRP number to the file name (\"Specification BUG-344\")". Bundle documents get the item ID in their file names (Specification, Implementation Plan, Walkthrough), so editor tabs identify the item. Affects the scaffold (New-LCM_Proposal), every tool that resolves bundle documents by name, the Control Hub document cache and Show CRP, tests, and RULE-LCM-009 (rule text change).
- Review: this Specification and the Walkthrough (one pre-existing test failure, one choice made without the operator). Operator decisions 2026-11-18: 2.1 names with a space, 3.1 only new and open bundles renamed; operator instruction to proceed to Gate 2 for a full review.

## 2. Gate 0 Contract
### Target State
- T1 New bundles are created as `Specification <ID>.md`, `Implementation Plan <ID>.md`, `Walkthrough <ID>.md`; the ledger fields `docs.*`, `plan_path`, `walkthrough_path` name them.
- T2 One resolver (`Resolve-LcmBundleDocumentPath`, `modules/ProposalSpecificationState.psm1`) returns the new name if present, else the legacy name; every tool that opened a bundle document by its fixed name uses it (ProposalManager, ProposalSpecificationState, Invoke-ProposalAction, Absorb-LcmContextRemark, Link-LcmLearnedAdvice, Fix-Documentation, Control Hub "Show CRP").
- T3 The bundles of all open items are renamed once; closed bundles keep the legacy names (history unchanged).
- T4 RULE-LCM-009 / RULE-LCM-011 (canonical and Claude adapter) and REQ-WINV-014 state the naming.

### Invariants and Exit Criteria
- No document becomes unreachable: legacy bundles resolve through the fallback.
- Parse / node gates; scaffold, ProposalManager, completion and specification-state tests pass except failures that also occur with the committed modules.

### Explicit Non-Goals
- Renaming closed bundles; changing the bundle folder names.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## Absorbed Operator Remarks

> show crp button works, but shows a design problem: the documents opened are not easily identified in the tabs headers!
> We need to append the CRP number to the file name ("Specification BUG-344")

(Operator, 2026-11-18; decisions 2.1 and 3.1 the same day.)
