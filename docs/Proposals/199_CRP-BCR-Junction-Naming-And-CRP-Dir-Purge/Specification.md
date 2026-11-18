# CRP-199: BCompare Junction Naming and Review Directory Cleanup

```yaml
CRP-ID: CRP-199
Scope: LCM_Inventory BCompare review lifecycle
Status: In Progress
Plan-State: in_progress
Progress-State: in_progress
Affected-Repos:
  - LCM_Inventory
```

## Objective

Make each BCompare review session use one deterministic live-junction name and
remove the complete CRP-scoped review scratch directory after a successful
review submission.

## Requirements

1. The live junction inside `BC_Review\<CRP>` MUST be named
   `Live_<RepositoryName>` without duplicating the CRP identifier.
2. Stale-junction cleanup MUST target only that exact live-junction name in the
   current CRP review directory.
3. Beyond Compare MUST remain the sole authority on review materiality. Its
   insignificant-difference rules determine what is shown; the staging audit
   records only explicit right-to-left selections from the visual review.
   relying on an incompatible array-to-list conversion.
4. Post-commit cleanup MUST resolve the CRP identifier from
   `.lcm_review.json`, remove junction nodes without traversing their targets,
   then remove only that CRP review directory.
5. If review metadata is unavailable, cleanup MUST retain the existing
   baseline-directory fallback.

## Exclusions

- Repository-wide ignore-rule changes are deferred.
- This CRP does not change review disposition, commit, or push policy.