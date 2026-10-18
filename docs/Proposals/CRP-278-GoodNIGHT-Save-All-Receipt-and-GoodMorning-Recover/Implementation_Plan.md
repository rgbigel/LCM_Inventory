# Implementation Plan: CRP-278 - GoodNIGHT Save-All Receipt and GoodMorning Recovery Gate

## 1. Executive Summary & Problem Context
CRP-278 owns the GoodNIGHT knowledge-persistence work split from CRP-277:
a durable Save All receipt and an actionable GoodMorning recovery gate.

## 2. Proposed Changes

### Component 1: Receipt Contract

- Delivered `GoodNightReceipt.psm1` as the durable, testable receipt
  contract.
- GoodNight writes the repository-scoped receipt only after
  `-SaveAllConfirmed` and a successful session-memory snapshot.
- The receipt includes the required timestamp, completion state, workspace,
  confirmation, session, and snapshot identities.

### Component 2: GoodMorning Recovery Gate

- GoodMorning reads and validates the receipt before its `-Auto` early return.
- Missing, malformed, incomplete, mismatched, and stale receipts produce a
  clear recovery instruction.
- The default GoodMorning path remains read-only. A valid receipt preserves
  the existing quiet `-Auto` behavior for short gaps.

## 3. Verification Plan

- Focused receipt state-machine tests pass.
- PowerShell AST validation passes for the module and both lifecycle tools.
- The workspace readiness gate reports `OK`.
