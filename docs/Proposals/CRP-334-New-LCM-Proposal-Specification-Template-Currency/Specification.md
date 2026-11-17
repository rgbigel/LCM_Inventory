# Specification: CRP-334

Module: docs/Proposals/CRP-334-New-LCM-Proposal-Specification-Template-Currency/Specification.md  
Purpose: Make the bundle scaffolding of New-LCM_Proposal write current, ledger-consistent metadata into new Specification files.  
Path: LCM_Inventory/docs/Proposals/CRP-334-New-LCM-Proposal-Specification-Template-Currency/Specification.md  
Authors: Rolf, Claude (Anthropic)  
Version: 10.6.4
Status: Suggested (registered)  
Date: 2026-11-15 15:44:55

```yaml
CRP-ID: CRP-334
Title: New-LCM_Proposal Specification Template Currency
Scope: LCM_Inventory
Target Scope: LCM_Inventory/modules/ProposalManager.psm1 (New-LCM_Proposal)
Affected Version Range: 10.6.4
Impacted Repositories: [LCM_Inventory]
Baseline-Version: 10.6.4
Author: Rolf, Claude
Date: 2026-11-15 15:44:55
Status: Completed
Plan-State: completed
Progress-State: completed
Priority: 5
App-ID: None
```

---

## 0. Registration Note

Created and registered by Claude (operator instruction 2026-11-15, WORKPLAN D-29) via `New-LCM_Proposal`. `Implementation_Plan.md` and `Walkthrough.md` are tool placeholders. Found while registering CRP-332.

## 1. Gate 0 Contract (RULE-GOAL-002)

- **Target State**: A Specification scaffolded by `New-LCM_Proposal` carries the current LCM version, the same priority as the ledger row, a DOX header (RULE-DOC-003) and the RULE-LCM-012 metadata.
- **Binding Principle**: "Cause no havoc: ask rather than invent or infer, and avoid unnecessary complexity."
- **Exit Criteria**: a test proposal created in a sandbox store shows `Baseline-Version` = `GlobalLCMVersion` of `inventory.json` and `Priority` equal to the ledger value; existing Specifications are still never overwritten; module parses and its Pester tests pass.
- **Explicit Non-Goals**: no change to id allocation, bundle naming, ledger schema or lifecycle; no rewrite of existing bundles.

## 2. Facts (2026-11-15, `ProposalManager.psm1`)

- The Specification template (lines 271-308) hard-codes `Baseline-Version: 10.2.1` and `Priority: High`; the ledger row gets `priority = 5` (line 393) and `lcm_version` from `inventory.json` (lines 358-367; fallback `10.2.3`). Template and ledger therefore disagree on both values.
- The template has no DOX header (Module, Purpose, Path, Authors, Version, Status, Date).
- The function has no `-Priority` parameter, so a caller cannot set it at registration.

## 3. Requested Changes

1. Use the resolved `$currentLcmVersion` for `Baseline-Version` (and compute it before the template is written).
2. One priority value for template and ledger; optionally a `-Priority <0..10>` parameter (default 5).
3. Add the DOX header to the template.
4. Replace the stale fallback `10.2.3` by reading `.agents/version.json`, or fail visibly when no version can be resolved.
