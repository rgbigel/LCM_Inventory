# CRP-260: Cohort Conflict Analysis and Push Gate

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-260` |
| Lifecycle State | `HELD` |
| Target Scope | Proposal cohort analysis and workspace push gating |
| Impacted Repositories | `LCM_Inventory`, `LCM_AI` |
| Priority | `7` |

## Proposed Semantics

`ANALYZE COMPLETE ALL` and `ANALYZE PUSH ALL` construct a computed cohort, exclude held,
rejected, cancelled, and deferred proposals without failure, and report real Git overlap,
merge, scope, and evidence risks before any lifecycle or publishing operation.

