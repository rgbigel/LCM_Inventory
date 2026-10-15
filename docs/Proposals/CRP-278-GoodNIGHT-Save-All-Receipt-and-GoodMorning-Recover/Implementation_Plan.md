# Implementation Plan: CRP-278 - GoodNIGHT Save-All Receipt and GoodMorning Recovery Gate

## 1. Executive Summary & Problem Context
CRP-278 owns the GoodNIGHT knowledge-persistence work split from CRP-277:
a durable Save All receipt and an actionable GoodMorning recovery gate.

## 2. Proposed Changes

### Component 1: Receipt Contract

- Define a durable, repository-scoped receipt location and schema.
- Make GoodNIGHT write the receipt after, not before, explicit Save All
  acknowledgement.
- Include timestamp, completion state, and session identity.

### Component 2: GoodMorning Recovery Gate

- Read and validate the receipt as part of the existing GoodMorning report.
- Display a clear remediation message when the receipt is missing, stale, or
  incomplete.
- Preserve GoodMorning's existing report and `-Auto` behavior unless an
  actionable receipt failure requires attention.

## 3. Verification Plan

- Add focused tests for the receipt state machine and GoodMorning reporting.
- AST-validate each changed PowerShell file.
- Run the workspace readiness gate.
