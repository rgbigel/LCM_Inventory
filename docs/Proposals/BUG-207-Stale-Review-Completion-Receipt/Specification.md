# BUG-207: Stale Review Completion Receipt

```yaml
Bug-ID: BUG-207
Priority: 9
Scope: Submit-ReviewResult completion validation
Status: Active
Plan-State: approved
Progress-State: in_progress
Affected-Repos:
  - Workspace_Inventory
```

## Defect

`Submit-ReviewResult.ps1` can record a `Completed` receipt against the current
HEAD commit when no current BCompare staging manifest exists. It does not commit
the live changes, yet reports successful completion and can purge an unrelated
stale CRP review scratch directory.

## Required Fix

Completion must fail without a staging manifest belonging to the requested CRP
and baseline. It must never create a completed receipt, identify a commit, or
purge review scratch when that validation fails.
