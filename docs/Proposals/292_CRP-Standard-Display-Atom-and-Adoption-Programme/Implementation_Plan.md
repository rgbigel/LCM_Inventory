# Implementation Plan: CRP-292 - Standard Display Atom and Adoption Programme

## 1. Suggested Programme Sequence

1. Complete and accept CRP-293 as the ShowCM typed-controller reference.
2. Execute CRP-294 for read-only web displays.
3. Execute CRP-295 for dense interactive table displays.
4. Execute CRP-296 and CRP-297 independently for native and console/launcher
   parity.

## 2. Governance Controls

- Every child must reference the Accepted Common Goal in CRP-292.
- Every implementation must be scoped to named surfaces and preserve existing
  behavior before replacement/removal.
- No child can start merely because a preceding child is suggested; its own
  Gate 1 acceptance remains required.

## 3. Programme Evidence

- Per-child specification, architecture, implementation, and walkthrough
  evidence where structural changes justify all four documents.
- Native parser/AST validation and focused automated tests.
- Rendered UI checks for web/native surfaces; terminal transcript checks for
  console surfaces.
- Disposable end-to-end contract tests for mutations.
