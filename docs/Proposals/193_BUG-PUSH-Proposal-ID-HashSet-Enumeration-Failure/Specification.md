# BUG-193: PUSH Proposal ID HashSet Enumeration Failure

```yaml
Bug-ID: BUG-193
Scope: LCM_Inventory push preflight
Status: In-Progress
Severity: High
Affected-Repos:
  - LCM_Inventory
```

## Problem

`Invoke-WorkspacePush.ps1 -ProposalIds` fails before lockstep preflight because it invokes `ToArray()` as an instance method on `HashSet[int]`.

## Root Cause

`ToArray()` is a LINQ extension method, not an instance method on PowerShell's generic hash set.

## Fix

Enumerate the hash set with PowerShell array syntax before passing proposal IDs to the push-plan resolver.
