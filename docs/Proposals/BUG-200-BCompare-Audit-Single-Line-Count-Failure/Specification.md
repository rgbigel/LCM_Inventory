# BUG-200: BCompare Audit Single-Line Count Failure

```yaml
Bug-ID: BUG-200
Scope: LCM_Inventory BCompare staging audit
Version: 8.4.0
Affected-Repos:
  - LCM_Inventory
Severity: High
Status: In-Progress
Root-Cause: A single meaningful line produced a scalar string, so StrictMode rejected its Count access.
```

## Problem

Closing the CRP-199 BCompare visual review invoked
`Audit-BeyondCompareReviewStaging`, which failed before creating a staging
receipt when a baseline file produced one meaningful line.

## Required Resolution

Normalize the directive-line pipeline to an array before its `Count` and index
operations. Preserve the existing handling for empty, single-line, and
multi-line baseline content.