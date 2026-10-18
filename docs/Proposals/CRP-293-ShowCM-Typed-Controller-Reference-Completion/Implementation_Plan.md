# Implementation Plan: CRP-293 - ShowCM Typed Controller Reference Completion

## 1. Design Steps

1. Catalogue current ShowCM state reads and mutations by explicit target kind:
   workspace, CRP, or COH.
2. Define request/response DTOs and schemas in the controller contract catalog.
3. Extract public controller handlers that call existing domain contracts
   without exposing internal state or command strings.
4. Convert the existing `workspaceSwitchAtoms` and lifecycle action handlers
   to typed request atoms.
5. Preserve browser-local filtering and rendering as local atoms.
6. Remove Standard Display reliance on generic `/execute` only after equivalent
   controller coverage and compatibility tests pass.

## 2. Verification

- Unit tests for each public controller and domain atom.
- Schema/contract tests for valid, stale, malformed, and unauthorized inputs.
- Disposable ledger integration tests for every mutating route.
- Browser tests for pending lock, confirmation, timeout, and structured errors.
- PowerShell AST, JSON schema, rendered artifact, and focused Pester checks.

## 3. Downstream Handoff

Publish a versioned atom/contract inventory that CRP-294 through CRP-297 can
adopt without copying ShowCM implementation details.
