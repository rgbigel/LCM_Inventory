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

## Implementation 0 Visual Prototype

`assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html` provides a desktop-only,
non-functional review surface. It shows the visible rail, standard display
controls, integrated filtering and sorting, proposal selection checkboxes,
the execution ledger, full-width cohort bulk actions, state facets, priorities,
failure/busy indications, and execution options. Data-world views are
intentionally delegated to Tool Explorer and other standard displays.

No lifecycle service, ledger schema, query-index implementation, operational
snapshot capture, or operational Control Hub behavior has changed. Focused
static validation and desktop-browser rendering passed; a BCompare review is
required before any commit.