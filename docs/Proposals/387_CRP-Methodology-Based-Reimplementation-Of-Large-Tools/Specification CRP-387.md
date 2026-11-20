# Specification: CRP-387

Module: docs/Proposals/387_CRP-Methodology-Based-Reimplementation-Of-Large-Tools/Specification CRP-387.md  
Purpose: Methodology Based Reimplementation Of Large Tools  
Path: LCM_Inventory/docs/Proposals/387_CRP-Methodology-Based-Reimplementation-Of-Large-Tools/Specification CRP-387.md  
Authors: Rolf, Claude  
Version: 10.8.4  
Status: Suggested  
Date: 2026-11-20 15:15:08

```yaml
CRP-ID: CRP-387
Title: Methodology Based Reimplementation Of Large Tools
Scope: LCM_Inventory
Baseline-Version: 10.8.4
Author: Rolf, Claude
Date: 2026-11-20 15:15:08
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent

Operator Gate 2 review 2026-11-20, item 9: "LCM_PushEligibility.psm1 is huge and should be re-implemented (learned
advice). I want a methodology based implementation. This may apply to other tools as well. Goals: atoms for
functional components and segmentation, potentially in GO or PY."

Measured 2026-11-20 (lines): `modules/ProposalManager.psm1` 4094, `modules/LcmPushRequalification.psm1` 470,
`tools/Invoke-LCM_Push.ps1` 438, `modules/LCM_PushEligibility.psm1` 307. The 4k figure matches ProposalManager, which
the push path imports; the push chain as a whole is the first candidate.

Binding guidance: learned advice "Model-Atom-Controller" (2026-11-09), "Atomizing" (2026-11-17), language direction
(Python default, Go for daemons, PowerShell only if unavoidable); RULE-PS-025 (files over 500 lines externalize blocks
into atoms).

- Review: this Specification only.

## 2. Gate 0 Contract (draft, for operator acceptance)

### Target State

T1 A method, written once (LCM_AI `docs/`), for re-implementing a tool: inventory of its functions and callers (tool
call xref), cut into atoms (one function each, registered as intent with its elevation flag), controller that only
orchestrates, model modules for persistence; language per atom (Python default, Go where a daemon or speed needs it).

T2 First application: the push chain (`Invoke-LCM_Push.ps1`, `LCM_PushEligibility.psm1`, `LcmPushRequalification.psm1`
and the parts of `ProposalManager.psm1` it uses), with unchanged behaviour (BUG-380 B12 and review item 10 included).

T3 A ranked list of further oversized tools with the same method applied later, each as its own CRP.

### Invariants and Exit Criteria

- Behaviour parity proven by tests derived from the rule IDs (not by the old tests alone); push dry run identical.
- No file over 500 lines in the re-implemented chain.

### Explicit Non-Goals

- No functional change of the push in the same step.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Open Operator Questions

- Language of the push chain atoms: Python (default) or Go (beside do.exe)?
- Schedule (operator 2026-11-20): done during the next release work.

## Operator Answer (2026-11-20 17:32:48)

- Language: Python (already answered; operator 2026-11-20). Long-running parts use the resident Python data service of CRP-382 (decision C) instead of their own daemons.
