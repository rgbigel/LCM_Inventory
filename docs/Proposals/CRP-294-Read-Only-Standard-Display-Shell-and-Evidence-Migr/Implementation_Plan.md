# Implementation Plan: CRP-294 - Read-Only Standard Display Shell and Evidence Migration

## 1. Migration Order

1. Inventory each display's data payload, keyboard behavior, print behavior,
   links, and existing filters.
2. Extract or version common shell/theme/provenance and local filter atoms.
3. Migrate one low-risk display first and compare its rendered result with its
   current artifact.
4. Migrate the remaining displays one at a time, retaining an equivalent
   fallback until their acceptance checks pass.

## 2. Verification

- PowerShell AST validation for every changed generator.
- Deterministic payload/render tests with `-NoLaunch`.
- Search, match-counter, theme, keyboard, and layout checks in a browser.
- Print/PDF checks for displays that currently support printing.

## 3. Exit Evidence

Record per-display adoption version, preserved capabilities, and any intentionally
excluded advanced behavior in the implementation walkthrough.
