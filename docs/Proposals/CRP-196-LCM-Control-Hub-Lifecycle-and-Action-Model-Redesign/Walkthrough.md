# Walkthrough: CRP-196

## Design Acceptance Record

The visible lifecycle and internal execution-ledger model were accepted for
further CRP-196 design work. The new visible statuses are `Open`, `Active`,
`Review`, `Complete`, `Published`, `Held`, and `Cancelled`; validation and
receipt phases remain internal evidence, not Control Hub statuses.

The accepted data-world direction uses direct NTFS access for authoritative
records, `es.exe` for tool discovery, an eventual LCM Query Index projection,
and port 9876 for commands and events only. Tool, interface, message, and
workflow contracts are indexable relationships.

The accepted design further requires visible Status, Plan State, Progress
Status, numeric priority from $0$ through $10$, `Busy doing <phase>`, and
`Failed for <reason>` indications. Equal-priority cohort members receive an
advisory technical recommendation order. Execution switches are visible,
editable, and recorded with each run. `Review Decision` is the mandatory
operator-facing review checkpoint; `Publish` is the user-facing action while `PUSH`
remains a compatible command alias.

Review support now includes a design for a CRP-specific, immutable snapshot
chain. On `accepted` or `accepted with changes`, the reviewed right-hand state
is captured as a new left-hand comparison candidate. The capture never changes
the live right-hand tree. Refreshed BCompare sessions can compare any retained
snapshot with the current live tree, allowing inspection of interstitial work
and manual backtracking after an invalidated decision. A final pushed-baseline
to-live roll-up review remains mandatory before local commit.

## Live Control Hub Read-Model

The root-owned Control Hub application presents the CRP-196 work-queue
read-model. It uses the accepted layout direction: visible lifecycle rail,
integrated search, numeric-priority ordering where values are already numeric,
proposal selection, state facets, and execution switches.

It additionally persists review-decision drafts for selected cohorts. A draft
captures the selected proposal identifiers, a fingerprint of the reviewed
scope, and effective switches without changing proposal state, staging files,
creating a review acceptance, committing, or publishing. Data-world views
remain delegated to Tool Explorer and related standard displays.