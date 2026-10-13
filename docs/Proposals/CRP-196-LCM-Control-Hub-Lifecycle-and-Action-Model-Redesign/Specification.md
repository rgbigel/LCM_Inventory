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

## Layout Direction and Authoritative UI Design Pattern

- **Governance Compliance**: The Control Hub implementation MUST strictly adhere to `DisplayStandardsPolicy.md` 10.0.0 (`RULE-DSP-001` through `RULE-DSP-016`), embedding the Antigravity-IDE Light Mode default palette with deep-slate topbar (`RULE-DSP-001`, `002`), `IBM Plex Mono` / `IBM Plex Sans` typography, and the two-row sticky header standard.
- **Authoritative Design Reference**: The design pattern and interactive UI architecture agreed upon in [`assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html`](file:///d:/Git_Repositories/LCM_Inventory/assets/CM_CONTROL_HUB_IMPLEMENTATION_0.html) serves as the authoritative UI specification and prototype for the Control Hub.
- **Top Row and Control Row**:
  - Global Topbar: Context badges, application title, active repository selector, and global status metrics.
  - Sticky Control Row: Search input with clear button, multi-facet status filter pills (`Open`, `Active`, `Review`, `Complete`, `Published`, `Held`, `Cancelled`), intern mode toggle, density selector, column visibility, and action triggers (`ShowTools`, `New Proposal`, `Sync`).
- **Lifecycle & Execution Rail**:
  - 7-stage Status Rail pipeline (`Open` -> `Active` -> `Review` -> `Complete` -> `Published`, with `Held` and `Cancelled` off-ramps).
  - Horizontal Execution Ledger timeline displaying checkpoints (`Scope`, `Baseline`, `Manifest`, `Verify`, `BCR Setup`, `Review`, `Commit`, `Publish`) with progress state indicators.
- **Vector Iconography**: Embedded Lucide SVG vector iconography (`RULE-DSP-005`) for all actions and status badges.
- **Selection & Bulk Cohort Action Panel**:
  - Full-width selection and bulk-action drawer positioned below the work table (`RULE-DSP-011`).
  - Cohort batch command triggers (`do`, `delete`, `defer`) exposing only actions valid for every selected proposal.
- **Read-Model Gating**:
  - The root-owned Control Hub application renders the live work queue. Its source and runtime labels MUST distinguish it from any retired visual prototype.
  - Data-world and contract views remain accessible via modal peek or delegated standard displays (e.g., Tool Explorer).

## Documentation Updates

### LCM_AI/Architecture
```markdown
### 10.0.0 Documentation Reconciliation Flow

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
repository. `LCM_Inventory/Cmd/FixDocumentation.cmd` exposes the bare-word command.
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