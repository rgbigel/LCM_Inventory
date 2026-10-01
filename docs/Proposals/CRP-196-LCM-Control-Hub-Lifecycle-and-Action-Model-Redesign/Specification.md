# CRP-196: LCM Control Hub Lifecycle and Action Model Redesign

```yaml
CRP-ID: CRP-196
Scope: LCM Control Hub and sidecar interaction model
Status: In Progress
Plan-State: approved
Progress-State: design
Affected-Repos:
  - Git_Repositories
  - LCM_Inventory
  - LCM_AI
```

## Objective

Replace inconsistent lifecycle terminology and unreachable status controls with
one visible lifecycle rail, an internal execution ledger, and a compact,
action-oriented Control Hub.

## Visible Lifecycle Contract

```text
Open -> Active -> Review -> Complete -> Published
Open | Active | Review -> Held -> Active
Open | Active -> Cancelled
```

The Control Hub shows three distinct state facets for every proposal:

- `Status`: the visible lifecycle status (`Open`, `Active`, `Review`,
  `Complete`, `Published`, `Held`, or `Cancelled`).
- `Plan State`: the governance decision state for the proposal plan.
- `Progress Status`: the current execution condition, including `Busy doing
  <phase>` while an internal phase runs.

`Held` records a required reason of `deferred`, `blocked`, or `failed`, rather
than creating separate lifecycle statuses. A failed test, review, commit, or
publication also shows a visible `Failed for <reason>` indicator while the
proposal remains in the appropriate recoverable lifecycle status.

`Review` is the Review Decision checkpoint. BCompare compares the pushed baseline to the
live working tree; the reviewer may widen display exclusions with `Peek`. An
accepted review creates the local commit and advances to `Complete`. A failed
test, requested change, or failed local commit returns work to `Active`; a
failed publish leaves it `Complete`. `Publish` is the user-facing action;
`PUSH` remains a backward-compatible command alias.

## Review Snapshot Chain

Every `accepted` or `accepted with changes` Review Decision captures an
immutable, CRP-specific snapshot of the reviewed right-hand state. Capturing a
snapshot never edits or restores the live right-hand working tree. It creates a
new left-hand comparison candidate only.

Snapshots are numbered and retained in chronological order. A refreshed
BCompare session may select any snapshot as its left-hand side and always uses
the current live working tree as its right-hand side. Selecting an older
snapshot provides an explicit backtrack point when a later decision invalidates
interstitial progress; it does not roll back files automatically.

Each snapshot records its parent snapshot or pushed baseline, accepted scope,
source review session, disposition, timestamp, and content manifest. Before a
local commit, the mandatory roll-up review still compares the pushed baseline
to the final live tree so incremental snapshot boundaries cannot hide a change.

## Execution Ledger and Data World

The Control Hub retains internal execution phases and evidence for scope,
baseline checkpoint, change manifest, verification, BCompare setup and
disposition, review snapshots, local commit, and publication. Verification depth is `Fast`,
`Focused`, `Standard`, `Deep`, or `Deferred`.

The LCM Query Index is an eventual structured projection over authoritative
NTFS records. It exposes proposal, repository, run, artifact, action, tool,
interface, message, and workflow relationships for the Control Hub and tools.
`es.exe` is the primary discovery partner for tools. The desktop daemon carries
commands and events, not canonical local data files.

## Priority, Cohorts, and Execution Options

Priority is an integer from $0$ through $10$, where $10$ is the highest
operator priority. The Control Hub displays priority, sorts cohort candidates
in descending numeric priority, and then applies a technical recommendation
order within equal-priority groups. The recommendation considers dependencies,
foundation-before-consumer order, risk, reversibility, and estimated validation
cost; it never overrides an operator-selected sequence.

Internal execution switches are visible and editable in the Control Hub. The
initial switch set includes verification depth, testing mode, review granularity,
BCR display scope, trace mode, and logging mode. Every run records the
effective switch values in its execution evidence.

## Layout Direction

- Use the standard display controls: presets, mode, Intern, filters, integrated
  sorting, reset filters, theme, refresh, help, and back.
- Keep App focus, search, and global commands in the top row.
- Replace the persistent sidecar with a full-width selection and bulk-action
  work area below the execution ledger.
- Expose only actions valid for every selected proposal in a bulk cohort.
- Show Status, Plan State, Progress Status, numeric priority, execution busy
  phase, failure indication, and effective execution switches in the selected
  proposal or cohort view.
- Keep data-world and contract views in Tool Explorer and related standard
  displays rather than in the primary proposal work queue.
- Record the static `CM_CONTROL_HUB_IMPLEMENTATION_0.html` as a visual-review
  prototype only; it has no operational behavior.

## Documentation Updates

### LCM_AI/Architecture
```markdown
### 3.4.2 Documentation Reconciliation Flow

`FixDocumentation <CRP/BUG scope>` reconciles explicit, repository-qualified
documentation payloads from selected proposal bundles. It produces a manifest
by default, applies only declared content with provenance markers when
authorized, and opens BCompare for every repository whose tripartite documents
change.
```

### LCM_AI/Requirements
```markdown
### REQ-LCM-196: Scoped Documentation Reconciliation

Documentation reconciliation MUST resolve repository-qualified payloads from
the selected CRP/BUG scope. It MUST reject missing scope, ambiguous payloads,
and competing updates for the same repository/document pair; it MUST NOT infer
delivery knowledge from unrelated work.
```

### LCM_AI/Implementation
```markdown
### 2.1 Scoped Documentation Reconciliation

`LCM_Inventory/tools/Fix-Documentation.ps1` reads declared CRP/BUG
payloads, writes a dry-run manifest or an applied receipt under the
repository-scoped temporary log root, and dispatches BCompare per changed
repository. `.lcm/Cmd/FixDocumentation.cmd` exposes the bare-word command.
```

### LCM_Inventory/Architecture
```markdown
## 5. Proposed Documentation Reconciliation Service

`LCM_Inventory` hosts `Fix-Documentation.ps1` as the evidence-bound
documentation reconciliation service. It receives explicit CRP/BUG scopes,
resolves repository-qualified tripartite payloads, records manifests and
receipts, and dispatches per-repository BCompare review without changing
implementation or lifecycle state.
```

### LCM_Inventory/Requirements
```markdown
### REQ-WINV-011: Scoped Documentation Reconciliation

`FixDocumentation` MUST default to dry-run, accept only explicit CRP/BUG
identifiers, and apply only declared fenced payloads. Applied changes MUST carry
provenance, produce an operational receipt, and undergo BCompare review before
commit.
```

### LCM_Inventory/Implementation
```markdown
### 3.1 Documentation Reconciliation Tool

| Tool Script | Role & Function | Key Parameters |
|:---|:---|:---|
| **`Fix-Documentation.ps1`** | Reconciles explicit, repository-qualified CRP/BUG payloads into tripartite documents. | `<CRP/BUG scope>`, `-Apply`, `-OpenReview`, `-Trace` |
```