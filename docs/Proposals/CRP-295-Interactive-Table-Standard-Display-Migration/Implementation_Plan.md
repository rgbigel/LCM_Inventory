# Implementation Plan: CRP-295 - Interactive Table Standard Display Migration

## 1. Design Sequence

1. Inventory each display's table schema, local actions, mutation routes,
   overlays, exports, and test baseline.
2. Validate the shared table/filter atoms against a read-only table before
   attaching mutations.
3. Convert actions to typed-controller intents one display at a time.
4. Add explicit target/selection confirmation and dispose stale overlays before
   replacing legacy action paths.

## 2. Verification

- Table-layout, resize, scroll, overlay, keyboard, and selection browser tests.
- Atom unit tests with representative inventory payloads.
- Contract and disposable persistence tests for every mutating display action.
- AST, `-NoLaunch` render, and repository-specific quality-gate checks.

## 3. Cross-Repository Gate

HA Inventory work requires a separately reviewed repository-local change set and
must not be mutated from the LCM_Inventory migration path.
