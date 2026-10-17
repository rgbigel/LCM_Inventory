# CRP-244: WHAT-IF Analysis Sub-Path Protocol and Trial Implementation Branching

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-244` |
| **Lifecycle State** | `SUPERSEDED` |
| **Successor** | [CRP-251: Sandboxed Prototyping Mode](../CRP-251-Sandboxed-Prototyping-Mode/Specification.md) |
| **Origin Repository** | `LCM_Inventory` |
| **Date** | 2026-10-13 |

## Supersession Decision

CRP-244 identified a valid goal: permit safe WHAT-IF investigation and trial
implementation when an analysis needs evidence beyond inspection alone. Its
original design relied on an isolated trial branch with rollback checkpoints.

[CRP-251](../CRP-251-Sandboxed-Prototyping-Mode/Specification.md) replaces
that mechanism with a stronger boundary: a disposable, non-production
environment that is isolated from live repositories, host registry state,
credentials, publishing, and destructive tools. Promotion is explicit and
creates a normal governed CRP; a sandbox result cannot become authoritative by
branch state or rollback alone.

No implementation began under CRP-244. Its goal and historical intake remain
preserved by this record and the proposal ledger.
