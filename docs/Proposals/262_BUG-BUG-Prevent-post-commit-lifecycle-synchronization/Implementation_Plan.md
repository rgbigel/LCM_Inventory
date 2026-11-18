# Implementation Plan: BUG-262 - [BUG] Prevent post-commit lifecycle synchronization failures

## 1. Executive Summary & Problem Context
CRP-261 Gate 2 completion created commit 10a894b before failing to synchronize the ledger when the proposal omitted cr_id and had not entered in_review. The fix safely matches optional identity fields and requires in_review before any commit.

## 2. Proposed Changes
### Component 1: Pre-commit lifecycle guard
- Safely resolve exactly one proposal by either optional identity field.
- Refuse completion unless the resolved proposal is already `in_review`.

### Component 2: Optional identity safety
- Apply property-presence guards to completion and BCR affected-repository lookup paths.
- Preserve current CRP/BUG identifiers without adding a required legacy field.

## 3. Verification Plan
- PowerShell AST parsing for the completion and BCR tools.
- Focused lifecycle Pester suite.
- Exact BUG-262 Beyond Compare review before completion.
