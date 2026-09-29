# BUG-195: Close Stale Beyond Compare Review Windows Before Relaunch

```yaml
Bug-ID: BUG-195
Scope: Workspace_Inventory Beyond Compare review launcher
Status: Completed
Severity: Medium
Affected-Repos:
  - Workspace_Inventory
```

## Problem

Repeated BCompare launches leave stale or erroneous review tabs open, making it
unclear which comparison is the active review.

## Fix

Before launching a replacement review, close existing BCompare review windows
whose title identifies the same repository.