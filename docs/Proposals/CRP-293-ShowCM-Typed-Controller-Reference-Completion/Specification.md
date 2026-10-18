# Change Request Proposal: CRP-293

```yaml
CRP-ID: CRP-293
Title: ShowCM Typed Controller Reference Completion
Scope: LCM_Inventory ShowCM, daemon controller, and public contracts
Baseline-Version: 10.0.1
Author: rgbig
Date: 2026-10-18
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: APP-001
Dependency: CRP-266 completed architecture; CRP-292 Accepted Common Goal
```

---

## 1. Goal Reference

Implements the Accepted Common Goal in [CRP-292 Specification.md](../CRP-292-Standard-Display-Atom-and-Adoption-Programme/Specification.md).

## 2. Objective

Make completed CRP-266 operational in ShowCM as the reference Standard Display:
replace state-changing generic shell-command dispatch with typed controller
requests that validate action identity, explicit target, expected revision, and
request shape before calling public domain contracts.

## 3. Required Capabilities

- Typed state, preview, and execute DTOs with versioned JSON schemas.
- Public controller routes for workspace switches and governed lifecycle
  actions; structured result, notice, and error responses.
- Revision-aware stale-state rejection.
- Front-end atoms that own only rendering, explicit input, pending lock,
  confirmation, and response display.
- Server/domain atoms that own policy, eligibility, cohort atomicity, and
  persistence.
- Generic `/execute` retained only for documented legacy compatibility.

## 4. Acceptance Criteria

- ShowCM no longer constructs generic PowerShell command strings for Standard
  Display actions.
- Invalid/stale/ambiguous requests return explicit structured errors and do not
  mutate state.
- Previewed impact equals executed impact for supported cohort operations.
- Existing Workspace switch behavior, filtering, action-menu overlay, and
  no-premature-success confirmation remain intact.
- Contract tests, disposable action integration tests, browser interaction
  tests, and AST/schema validation pass.

## 5. Non-Goals

- Do not migrate any other Show display in this CRP.
- Do not reopen or alter CRP-266.
- Do not redesign lifecycle policy or bypass current review gates.
