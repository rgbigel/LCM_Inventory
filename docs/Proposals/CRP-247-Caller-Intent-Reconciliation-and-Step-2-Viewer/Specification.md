# CRP-247: Caller Intent Reconciliation and Step 2 Viewer

| Metadata Field | Value |
|---|---|
| **Proposal ID** | `CRP-247` |
| **Lifecycle State** | `IN_PROGRESS` (`DO 247` activated implementation) |
| **Origin Repository** | `LCM_Inventory` |
| **Target Scope** | `CON-001-L01` alternative-branch refinement, derived caller-intent evidence, LCM Analysis Viewer presentation, and ADMINMODE rule-change authorization |
| **Affected Version Range** | LCM_Inventory analysis tooling `v7.0.0+`; viewer `v1.2.0+`; Analysis and Review Governance Policies `v9.0.0+` |
| **Impacted Repositories** | `["Git_Repositories", "LCM_Inventory", "LCM_AI"]` |
| **Author** | Rolf, LCM_AI Engine |
| **Date** | 2026-10-05 |
| **Flow Mode** | Normal review cycle |

## 1. Problem Statement

The immutable Level 1 baseline
`data/analysis/history/CON-001-L01-R004.json` records 324 public parameter
gates as `parameter-gate-not-found`. Published CRP-121 dependency evidence
establishes uniquely resolved production callers for 23 of those gates.

Caller and callee contracts reconcile the purpose of those 23 gates, but the
current analysis model and viewer cannot retain that derived evidence or show
the operator-approved coverage breakdown. The immutable Step 1 baseline must
not be edited.

The current Level 1 runner also evaluates only the first condition of each
PowerShell `IfStatementAst`. It therefore omits `elseif` conditions and does
not retain `else` fallback behavior as an explicit branch.

Rule changes currently enter ordinary documentation review although the rule
author has already specified the intended governance behavior. Rule mutation
therefore requires a separate, non-elevation authorization gate and durable
actor attribution.

## 2. Objective

Create a new immutable Step 2 caller-intent reconciliation artifact that:

1. references R004 and the published CRP-121 forward/reverse indexes;
2. stores source-linked caller evidence, confidence, relevance, and
   non-destructive disposition for each reconciled gate;
3. preserves `parameter-gate-not-found` as the baseline result;
4. reports direct documentation coverage separately from caller-context
   coverage, while showing their combined total; and
5. extends the LCM Analysis Viewer to present this derived coverage tier and
   per-gate reconciliation status, searchable table content, and tri-state
   metric-button filtering.
6. emits one Level 1 branch record for every `if` and `elseif` condition and
   one explicit, non-conditional fallback record for each `else` branch.
7. gates staged rule changes through hidden ADMINMODE, using Windows local
   Administrators membership independently of elevation and logging the actor.
8. inventories every public PowerShell parameter for scoped `.PARAMETER` help
   evidence as the CmdletBinding adapter for the pre-existing universal
   script-header/help requirement.

## 3. Settled Analysis Inputs

| Item | Value |
|---|---:|
| Public parameter gates in R004 | 636 |
| Directly documented Step 1 gates | 312 |
| Unresolved Step 1 gates | 324 |
| Reconciled caller-context gates | 23 |
| Remaining unresolved gates | 301 |
| Total documented coverage after reconciliation | 335 / 636 (52.67%) |

The 23 reconciled records are source-linked `retain-entrypoint` findings and
have zero deletion eligibility. The 208 CRP-121 candidate-dead-code records
are explicitly out of scope: they are not deletion recommendations.

The R004 figures remain retained historical evidence. The alternative-branch
refinement produces the current R007 figures: 321 direct, 23 caller-context,
344 total documented, and 304 unresolved public parameter gates.

## 4. Scope

### In scope

- A new immutable derived JSON artifact under `data/analysis/history/`.
- A deterministic generator that reads existing immutable evidence and writes
  only a new artifact; it must refuse overwrite.
- Viewer support for direct, caller-context, combined, and unresolved coverage.
- Per-record viewer filtering and display of derived status, relevance,
  confidence, caller source, and disposition.
- Tri-state metric buttons: white ignores a filter, green includes matching
  records, and red omits matching records. Functional Elements is green-only.
- Complete public-parameter help records in the viewer so Header/Help metric
  buttons filter auditable records rather than only display a summary.
- Qualified global search with implicit AND, explicit `AND`/`+`, `OR`/`|`,
  `!`, parentheses, quoted phrases, and `repo:`, `source:`, `element:`,
  `type:`, `docs:`, and `results:` prefixes.
- Editor source links that use the active VS Code URI protocol and exact
  line/column.
- Runbook documentation for the Step 2 generation and retention workflow.
- A new immutable Level 1 run that records `if` alternatives and fallbacks.
- Hidden ADMINMODE initialization, operator command, and pre-commit rule gate.
- Architecture documentation of the ADMINMODE authorization rationale.
- Complete PowerShell public-parameter header/help inventory, reported
  separately from parameter-gate coverage.

### Out of scope

- Editing or regenerating R004.
- Altering CRP-121 forward or reverse indexes.
- Deleting, changing, or proposing removal of code.
- Treating ambiguous, dynamic, external, or unresolved edges as caller proof.
- Requirement-anchor and remediation analysis, reserved for Step 2D.
- `try` / `catch` / `finally`, `trap`, and `switch` extraction. These
  constructs are explicitly deferred to a future CRP.

## 5. Acceptance Criteria

1. The generator produces an immutable artifact named after its selected
   immutable baseline, for example
   `CON-001-L01-R007-S020-CallerIntentReconciliation.json`.
2. The artifact records input paths and SHA-256 hashes for R004 and both
   dependency indexes.
3. Exactly 23 records have `documentation_tier: caller-context`; no other
   Level 1 result is reclassified.
4. The artifact reports 312 direct, 23 caller-context, 335 total documented,
   and 301 unresolved gates.
5. The viewer visibly labels caller-context coverage and cannot imply that
   all 335 gates were directly documented.
6. The viewer provides no deletion action or removal recommendation.
7. Focused JSON, PowerShell AST, and viewer-generation validation pass.
8. The viewer combines green include and red omission metric filters, exposes
   header/help audit records, accepts qualified grouped queries, and its
   source links open the recorded editor line and column.
9. The new Level 1 run distinguishes `if`, `elseif`, and `else` with stable
   branch-kind and branch-index fields. An `else` fallback is not classified
   as a parameter documentation failure.
10. Rule changes cannot be committed unless ADMINMODE is enabled for the same
   eligible user SID; every authorization or denial records actor, SID, CRP,
   and paths in the CM log.
11. Each Level 1 run reports a complete PowerShell public-parameter
    header/help inventory. Its `.PARAMETER` evidence is not a PowerShell-local
    rule; it implements the existing universal script-header/help rule.

## 6. Risks and Controls

| Risk | Control |
|---|---|
| Derived results overwrite baseline evidence | New immutable filename and refusal to overwrite. |
| Caller context is mistaken for direct documentation | Separate direct and caller-context metrics and labels. |
| Static ambiguity is mistaken for a resolved caller | Accept only published `production` + `resolved` edges. |
| Viewer encourages deletion | Exclude deletion controls and retain explicit zero eligibility. |
