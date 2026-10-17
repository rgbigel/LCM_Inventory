# Implementation Plan: BUG-288 - [BUG] Priority action advances held proposal lifecycle state

## 1. Executive Summary & Problem Context
BUG-288 captures priority-action lifecycle isolation for later repair; implementation is held.

## 2. Proposed Changes
### Component 1: Priority-only mutation
- Ensure a priority update changes only priority metadata and its audit history.
- Preserve a held proposal's state, progress state, and review hold.

## 3. Verification Plan
- Add a focused held-proposal priority regression test.
- Verify lifecycle fields before and after each priority value.
