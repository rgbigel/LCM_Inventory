# Implementation Plan: CRP-280 - Catalog-Synced Show Command Macros and Managed Alias Maintenance

## 1. Executive Summary & Problem Context
The workspace has a durable macro convention but no deterministic registration
path for catalogued `Show*` commands and no bounded maintenance action for
other aliases. This CRP separates safe generated entries from intentional
operator-maintained command definitions.

## 2. Proposed Changes

### Component 1: Definition Model and Parser

- Add a parser/writer that recognizes generated and manual macro sections
  without rewriting unrelated documentation.
- Define catalog eligibility, name/alias normalization, and target-validation
  rules.

### Component 2: `Show*` Synchronizer

- Derive eligible `Show*` entries from the authoritative tool catalog.
- Add dry-run, synchronization, and validation modes.
- Emit deterministic diagnostics for missing targets and collisions.
- Define one display-host contract for every standard display command:
  IDE-hosted by default, browser-only when explicitly requested, and a
  non-launching diagnostic when the host lacks IDE display support.

### Component 3: Manual Maintenance Sub-Action

- Add explicit add, update, retire, list, and validate actions for
  non-`Show*` commands and legacy aliases.
- Require complete operator-supplied definition metadata before mutation.

### Component 4: Tests and Documentation

- Add focused tests for parser stability, generated/manual separation,
  collision handling, alias migration, and dry-run behavior.
- Document direct invocation versus conversational macro conventions.

## 3. Verification Plan

- Run focused Pester tests for the synchronizer and maintenance sub-action.
- AST-validate changed PowerShell files.
- Validate generated output against the existing macro-definition formatting
  contract and run the workspace readiness gate.
