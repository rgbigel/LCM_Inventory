# Implementation Plan: CRP-279 - Lifecycle Status Failure Diagnostics and Escape Routes

## 1. Executive Summary & Problem Context
Lifecycle failures currently surface as isolated exceptions. Operators must
manually reconstruct the intended status change, direct failing targets,
governing conflict, and compliant remediation. CRP-279 introduces one shared
diagnostic contract without changing lifecycle decisions.

## 2. Proposed Changes

### Component 1: Failure-Report Model

- Define typed report, per-target failure, provenance, and escape-route
  records in the lifecycle module.
- Classify known lifecycle failure categories and retain unresolved evidence
  explicitly.
- Distinguish direct target failures from indirect blockers.

### Component 2: Lifecycle Integration

- Wrap lifecycle intent entry points at `Invoke-ProposalAction.ps1` and
  Control Hub dispatch boundaries.
- Convert expected lifecycle failures into the structured report while
  preserving nonzero failure behavior for automation callers.
- Leave unexpected implementation failures explicit and include only verified
  diagnostic context.

### Component 3: Provenance and Escape Analysis

- Map lifecycle guards to repository, source symbol, rule identifier, and
  documentation location.
- Produce ranked compliant remedies with a hard maximum of three.
- Require a subsequent explicit operator command for every route.

### Component 4: Rendering and Evidence

- Add compact console rendering and reusable object serialization.
- Add durable receipts only if an existing, non-commit-authorization evidence
  location is approved by the lifecycle model.

## 3. Implemented Scope

- Added shared report construction, rendering, and report-backed exception
  helpers in `ProposalManager.psm1`.
- Integrated recognized `Invoke-ProposalBatchAction` validation failures
  without changing their nonzero failure behavior.
- Preserved original exception text for automation callers while attaching
  serialized report data to the exception.
- Rendered the report as the CLI error payload so the existing Control Hub
  daemon error surface presents the concise operator-facing diagnostic.
- Added focused direct-target, provenance, route-cap, and non-mutation tests.

## 4. Verification Plan

- Run focused lifecycle and Control Hub safety Pester tests.
- Run PowerShell AST validation for the module, action script, and tests.
- Run workspace readiness validation before BCR.
