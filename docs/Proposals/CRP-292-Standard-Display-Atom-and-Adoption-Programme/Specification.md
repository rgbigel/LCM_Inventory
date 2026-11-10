# Change Request Proposal: CRP-292

```yaml
CRP-ID: CRP-292
Title: Standard Display Atom and Adoption Programme
Scope: LCM_Inventory and governed display repositories
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 14:59:30
Status: Superseded
Plan-State: superseded
Progress-State: deferred
Priority: High
App-ID: APP-001
```

---

## 1. Accepted Common Goal

Establish one reusable, governed Standard Display system across LCM web, native,
and console presentation surfaces. It must provide consistent visual language,
accessible interaction atoms, reliable state feedback, and verifiable behavior
without copying ShowCM wholesale, forcing a common UI technology, or weakening
domain governance.

Every Standard Display must remain a thin presentation layer: it renders
authoritative data, collects explicit operator intent, and presents outcomes.
Only typed controller and domain contracts determine eligibility, mutation, and
persistence.

## 2. Programme Contract

- [DisplayStandardsPolicy.md](../../../.agents/rules/DisplayStandardsPolicy.md)
  remains authoritative for web, native, console, and dispatch requirements.
- Completed CRP-266 defines the controller/domain boundary. It is not reopened
  or modified by this proposal.
- CRP-293 operationalizes that boundary in ShowCM and is the required reference
  acceptance before any child migration starts.
- CRP-294 through CRP-297 are independently reviewable child paths. None may
  infer implementation approval from this umbrella proposal.

## 3. Shared Atom Families

1. Web shell: theme persistence, provenance, topbar, compact toolbar, keyboard
   actions, responsive layout, and stable table geometry.
2. Data interaction: qualified search, filters, match counter, selection, and
   deterministic rendering.
3. Action interaction: explicit target, preview, pending lock, typed dispatch,
   structured success/error display, refresh, and timeout.
4. Native parity: dialog hierarchy, DPI resilience, interactive desktop
   dispatch, and single-instance lifecycle.
5. Console parity: structured ASCII/ANSI output, progress atoms, explicit
   diagnostics, and deterministic launcher behavior.

## 4. Explicit Non-Goals

- No blanket HTML conversion of native or console tools.
- No duplicate lifecycle policy in browser code.
- No generic PowerShell command strings as the Standard Display mutation
  interface after the CRP-293 reference is accepted.
- No bulk styling rewrite without per-display behavior and accessibility tests.

## 5. Programme Exit Criteria

- Each adopted display retains its current supported behavior.
- Each state-changing adopted display has typed contract and disposable
  integration coverage.
- Each display family meets its applicable policy requirements and records
  focused render, interaction, and syntax evidence.
- Child work is completed only through its own lifecycle and BCR scope.
