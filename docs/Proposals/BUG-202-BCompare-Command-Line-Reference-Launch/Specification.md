# BUG-202: BCompare Command-Line Reference Launch

```yaml
Bug-ID: BUG-202
Scope: LCM_Inventory BCompare launch dispatch
Version: 8.4.2
Affected-Repos:
  - LCM_Inventory
Severity: High
Status: In-Progress
Root-Cause: The launcher replayed a long folder-compare command line through the interactive desktop bridge after already writing a named BCompare session.
```

## Problem

Launching `Invoke-BeyondCompareReview.ps1` first opened Beyond Compare's
command-line reference instead of the requested review session.

## Required Resolution

Launch the configured named BCompare session directly. Do not replay the
folder paths, titles, filters, and read-only switches through the interactive
desktop bridge.