# Requirements Specification: Workspace Inventory & Configuration Management Engine

Module: docs/Requirements.md  
Purpose: Normative technical requirements, environmental prerequisites, safety boundaries, and compliance constraints for LCM_Inventory.  
Path: D:/Git_Repositories/LCM_Inventory/docs/Requirements.md  
Authors: Rolf, LCM_AI Engine  
Version: 10.2.0
Status: Authoritative Requirements  
Date: 2026-10-13

---

## 1. Environmental Prerequisites & Platform Constraints

1. **PowerShell Runtime**: Must execute on **PowerShell 7.4+ (`pwsh`)** with `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`. Windows PowerShell 5.1 is prohibited.
2. **Operating System**: Windows 11 64-bit with NTFS file system supporting symbolic links and volume mount junctions.
3. **Execution Privilege**: Default un-elevated (User) context. Tools requiring administrator privileges must route through `Start-ScriptProcessElevated.ps1` with the non-auto-close invariant (`RULE-ELEV-001` - `006`).
4. **Encoding & Line Endings**: UTF-8 without BOM, CRLF line endings, 2-space JSON and Markdown indentation (`INVARIANT-RULES`).

---

## 2. Normative Invariants & CM Governance Rules

### REQ-WINV-001: Review Gate Enforcement (`RULE-REV-001`)
- No automated tool or AI assistant `MAY` commit changes to Git repositories without explicit operator visual review through the Macrium BCR flow (`Invoke-MacriumBcrReview.ps1` and the Beyond Compare 5 `_LCM` profile).
- Direct invocation of `git commit` outside the review runner is strictly prohibited during interactive development.

### REQ-WINV-002: Audit Receipt Generation & Persistence (`RULE-REV-003`)
- Every approved commit `MUST` produce an immutable audit receipt in `LCM_Inventory/data/reviews/review_<Repo>_<timestamp>.json`.
- Receipts must record repository name, target branch, commit hash, commit message, and changed file paths.

### REQ-WINV-003: Single Source of Truth for Proposals (`RULE-LCM-001`)
- All change requests, bug fixes, and feature proposals `MUST` be registered in `LCM_Inventory/data/proposals/proposals.json`.
- Proposals must contain: unique integer `id`, `title`, `state`, `origin_repo`, `priority`, and formal `plan_path`.
- **Legacy Backward Compatibility Guard**: When parsing legacy proposals, imported historical records, or external CRPs where `origin_repo` is absent or null, tools and consumers `MUST NOT` throw runtime exceptions or break proposal ingestion. They `MUST` fallback gracefully to `'LCM_Inventory'` (or root repository context) and log a non-fatal warning for metadata backfill.

### REQ-WINV-004: Workspace Audit & Drift Detection (`RULE-EFF-001`)
- `Invoke-WorkspaceAudit.ps1` `MUST` inspect all LCM-governed repositories under `D:\Git_Repositories`, assessing:
  - Git repository validity and current branch.
  - Working tree dirty state (clean vs uncommitted changes).
  - Tracking status (ahead/behind remote origin).
  - Absorbed LCM baseline parity against `GlobalLCMVersion`.
  - NTFS junction health pointing to `.agents/rules`.

### REQ-WINV-005: Lockstep Multi-Repository Push (`RULE-LCM-013`)
- `Invoke-WorkspacePush.ps1` `MUST` conduct pre-push validation (Gemini rules export and tool catalog synchronization).
- It `MUST` iterate across all ahead repositories, execute `git push origin <branch>`, log structured audit records to `logs/cm_activity.log`, and transition completed proposals to `pushed`.
- **Directional Lockstep Invariant (`LCM_Shared` <-> `LCM_Inventory`)**: Any code, atom, or documentation change in `LCM_Shared` updates its repository version and commit hash, which `MUST` be reflected in `LCM_Inventory` (`inventory.json`). Therefore, pushing `LCM_Shared` without simultaneously pushing `LCM_Inventory` is prohibited. Conversely, pushing `LCM_Inventory` in isolation is valid for routine inventory data, audit receipts, and telemetry commits, *unless* an inventory tool change or contract update modifies/inspects `LCM_Shared`, which again couples both in lockstep.

### REQ-WINV-006: Runtime Presentation Artifact Isolation (`RULE-DSP-008` / `CRP-156`)
- All generated HTML dashboard reports, document viewers, and temporary interactive tables `MUST` be written to `data/artifacts/` or `data/staging/`.
- Generated HTML runtime views `MUST NOT` be committed to repository `docs/` directories.

---

## 3. UI/UX Display Standards Compliance

All interactive viewers in `LCM_Inventory` (such as `Show-CmControlHub.ps1`, `Show-WorkspaceInventoryApp.ps1`, `Show-WorkspaceReadiness.ps1`) `MUST` conform to [`DisplayStandardsPolicy.md`](file:///D:/Git_Repositories/.agents/rules/DisplayStandardsPolicy.md):
1. **Canonical Token Architecture**: Must inherit styles from `StandardTableDisplay.css` (Glassmorphic dark mode, hsl custom properties).
2. **Double-Row Sticky Table Headers**: Row 1 for column titles and multi-column sorting; Row 2 for live filter inputs.
3. **Action Logging Drawer**: Must provide collapsible floating audit drawer capturing all desktop dispatches with timestamps and exit codes.
4. **Desktop Dispatch Routing**: Must invoke native applications via background runners without terminal focus stealing (`RULE-PS-012`).

---

## 4. Constituent Module Inspection & Contract Governance Tools [Draft Concept]

> [!NOTE]
> **Draft Status Warning**: This section represents an exploratory architectural working concept and is **currently NOT the authoritative source of truth**. It defines planned inspection tools hosted and versioned by `LCM_Inventory` to audit external satellite modules (such as `LCM_Shared`).

### REQ-WINV-007: Contract Verification Engine (`ShowContracts`)
- `LCM_Inventory` `MUST` host `Show-Contracts.ps1` (`ShowContracts`) to inspect, visualize, and verify public contract specifications, schema invariants, parameter assertions, and return-type expectations across constituent modules.
- It `MUST` audit consuming repositories for contract adherence and detect drift between declared contracts and consumer usage.

### REQ-WINV-008: Interface & Module Structure Discovery (`ShowInterfaces`, `ShowModules`)
- `LCM_Inventory` `MUST` host `Show-Interfaces.ps1` (`ShowInterfaces`) to enumerate exported PowerShell functions, cmdlets, classes, and parameter bindings across workspace modules.
- `LCM_Inventory` `MUST` host `Show-Modules.ps1` (`ShowModules`) to map manifests (`.psd1`), root scripts (`.psm1`), dependency trees, and load order hierarchies.

### REQ-WINV-009: Granular Atom Inventory (`ShowAtoms`)
- `LCM_Inventory` `MUST` host `Show-Atoms.ps1` (`ShowAtoms`) to catalogue pure, reusable atomic functions ("Atoms") with their test coverage, Pester test links, and consumption metrics.

### REQ-WINV-010: Constituent Component Version Registry
- `LCM_Inventory` `MUST` maintain an authoritative registry (`inventory.json`) recording the exact versions, commit hashes, and dependency states of all external satellite modules (e.g., `LCM_Shared`), while allowing each satellite module repository to maintain its own independent source code versioning lifecycle.

<!-- FixDocumentation: CRP-196 Requirements -->
### REQ-WINV-011: Scoped Documentation Reconciliation

`FixDocumentation` MUST default to dry-run, accept only explicit CRP/BUG
identifiers, and apply only declared fenced payloads. Applied changes MUST carry
provenance, produce an operational receipt, and undergo BCompare review before
commit.
<!-- /FixDocumentation -->

### REQ-WINV-012: Recovery Lifecycle, Cohort, and Review Contract

- The authoritative current lifecycle representation MUST be the flat
  `state`/`state_reason` pair. `state_reason` records why the current state
  applies; it is not a second state axis.
- Existing history MUST remain immutable. Newer lifecycle events MUST append
  forward-only records and may add transition, cohort, reviewer, test-scope,
  and delta metadata without rewriting prior records.
- CRP bundles are temporary active specifications. A successful push absorbs
  delivered intent into baseline documentation. Reopened work MUST reuse the
  same identifier, return it to `suggested`, and append a revision record.
- A semantic active-specification change MUST restart affected CRPs at
  `suggested` and limit renewed review/testing to the documented semantic
  delta. Cohort coordination bundles MAY define shared repository/cohort
  members and verification.
- BCR MUST remain the principal visual review mechanism. `ShowCM` MUST support
  overview plus requested state navigation, including accept/reject and
  repository, cohort, and complete forms.
- Generated artifacts, scratch content, data, logs, and routine test output
  MUST NOT require review. BCR MAY inspect those paths unfiltered on request,
  and tools MAY provide non-blocking advisory findings. Managed lifecycle hooks
  remain in force for governed changes.

### REQ-WINV-013: Cohort Identity, Resolution, and Gate Contract (CRP-259)

- Every lifecycle, membership, review, or completion request MUST resolve one
  explicit **Item** target: an individual CRP/BUG or a declared COH. `CRP` and
  `COH` are different target kinds. Resolution MUST NOT fall back to a row,
  repository, prior selection, or merely active cohort when a selector is
  required.
- A cohort identity MUST be `COH-<prime>`, where `<prime>` identifies its
  single head CRP/BUG. A cohort is invalid unless that head exists, belongs to
  the cohort, and is its only head. Additional members are optional.
- There MUST be no more than one active/open cohort. Inactive/closed cohorts
  are retained as closed evidence. Creating an inactive cohort while an active
  cohort exists is permitted. Opening an inactive cohort MUST atomically close
  the existing active cohort before opening the selected one and MUST refuse if
  it would leave two active cohorts.
- Adding a member without a cohort selector is permitted only when exactly one
  active cohort exists; it targets that cohort. All membership and lifecycle
  changes MUST validate the complete prospective cohort before persistence and
  MUST roll back as a unit on validation or persistence failure.
- Before Gate 2 continuation, a COH operation MUST automatically synchronize
  every declared member to the required gate state. Synchronization is
  fail-closed: an unmet precondition, invalid evidence, unresolved target, or
  member error stops the operation, starts no BCR, and advances no member.
  Gate-state equivalence is satisfied only by the same required lifecycle gate
  with valid evidence; a similarly named or later-looking state is not a
  substitute.
- Once alignment succeeds, the system MUST launch and record exactly one BCR
  for the resolved cohort scope. Its disposition MUST enumerate and resolve
  every member. Individual CRP BCRs remain individual scopes and MUST NOT be
  represented as cohort acceptance.
- Gate 1 is the CRP planning/activation halt. Gate 2 is the aligned visual BCR
  decision. `DOIT` is a flow switch that may cross Gate 1 execution pauses but
  MUST stop at Gate 2; it is never a Gate 2 bypass. Lifecycle actions,
  including open/close, synchronization, BCR disposition, completion, and
  their audit records, MUST be atomic.
- The Control Hub MUST expose deterministic row actions appropriate to the
  row's Item kind and state, disable or refuse invalid actions, and show the
  resolved target, member dispositions, synchronization/no-op result, BCR
  result, and failure reason in both result UI and append-only audit evidence.
