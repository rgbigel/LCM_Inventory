# BUG-194: PUSH Omitted Repository Filter Normalization

```yaml
Bug-ID: BUG-194
Scope: LCM_Inventory push preflight
Status: Completed
Severity: High
Affected-Repos:
  - LCM_Inventory
```

## Problem

A full-cohort `PUSH` without `-Repositories` passes an empty filter value to the
push-plan resolver, which rejects it as an empty repository name.

## Fix

Normalize omitted and blank repository filters before resolving the push plan.