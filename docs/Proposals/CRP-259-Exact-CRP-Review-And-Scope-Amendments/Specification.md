# CRP-259: Control Hub Targeted Actions and Flow Redesign

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-259` |
| Lifecycle State | `IN_PROGRESS` (`DOIT`) |
| Target Scope | LCM Control Hub targeted CRP/cohort operation model |
| Impacted Repository | `LCM_Inventory` |
| Priority | `10` |

## Objective

Replace the Control Hub's ambiguous selection and duplicated lower workspace with explicit
targeted operation. The active target is always one CRP or one cohort, and actions apply to
that target only.

## Requirements

1. Replace `SHOW` with `ACTIONS` and remove the lower workspace while preserving its
   lifecycle, cohort, maintenance, and information capabilities.
2. Provide an explicit `ITEM: CRP-<id> | COH-<prime>` target selector. No switch or action
   may infer a target from a row, the first visible proposal, or a previous selection. A row
   action must switch ITEM explicitly to that row's target before it can operate.
3. Provide a Flow Switches surface for persistent target settings. Standard settings use
   green emphasis and controlled non-default settings use the existing DOIT amber emphasis.
4. Retain stronger warning treatment for FIX exceptions. `-Force` and `-Immediately`
   remain distinct governed mechanisms under one visible `FIX` action group.
5. Define a cohort as a head/prime CRP and zero or more additional member CRPs. Its identity
   is `COH-<prime>`, anchored by that head/prime, and it may contain that sole CRP; no
   two-member minimum exists. Membership proposals preview and atomically add or remove one or
   more non-head members. They validate that the prime is retained, every member belongs to the
   same repository, and no duplicate member exists. At most one active/open cohort may exist,
   while multiple inactive/closed cohorts are permitted. Add has no cohort selector: it
   resolves the sole active/open cohort automatically and displays its read-only identifier;
   adding with no active/open cohort fails with a clear no-active-cohort error. Creation remains
   available while another cohort is active/open, but creates an inactive cohort. Activating or
   opening an inactive cohort is rejected while an active/open cohort exists.
6. Add Retire and Supersede actions. Supersede requires a successor CRP and records both
   sides of the relationship.
7. Move workspace maintenance to a separate Maintenance control beside ITEM. It must not
   be presented as an action on the target.
8. The target action matrix is:
   - CRP: lifecycle actions, documents, flow settings, and FIX actions.
   - COH: member visibility, cohort review, flow settings, membership editing, and cohort
     hold, reopen, and close actions.
   - Workspace: maintenance actions only.

   A selected COH action resolves all current cohort members at action time; it cannot use a
   partial, cached, or row-derived member set.
9. Cohort lifecycle actions apply atomically to every resolved current member, including a
   valid sole head/prime member. If any member is ineligible, the action is rejected with the
   member-specific reason and no member changes. `DOIT` is a flow gate, not authority to force
   an unsafe lifecycle mutation or bypass validation, atomicity, or review prerequisites.
10. At Gate 1, verification, BCR, and completion, an active/open declared cohort is
    automatically synchronized to the shared required gate state before continuation. Each
    current member may be verified only from existing validated evidence and required
    preconditions. Any failed member stops the operation with its member-specific error: no BCR
    begins and no member receives a partial gate advance. An already aligned result is a no-op.
    Record synchronization, evidence/precondition checks, no-op outcomes, and the result in
    audit metadata.
11. At BCR Gate 2, after every cohort member is aligned, the Control Hub initiates one BCR for
    the exact resolved cohort scope. Continuation is rejected until every member has a recorded
    disposition for that scope. Do not initiate BCR at the planning gate. Only an explicit
    authorized BCR bypass may satisfy this requirement; `-Force` and `-Immediately` remain
    distinct mechanisms and do not imply a BCR bypass.

## Scope Boundary

CRP-259 delivers the Control Hub user interaction redesign and reuses the current validated
proposal and cohort services. CRP-266 subsequently establishes the typed display-controller
architecture and reference migration.
