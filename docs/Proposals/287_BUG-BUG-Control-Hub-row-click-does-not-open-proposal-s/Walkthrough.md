# Walkthrough: BUG-287 - [BUG] Control Hub row click does not open proposal specification

## 1. Executive Summary
BUG-287 records the missing specification-first behavior for Control Hub CRP and BUG row clicks.

## 2. Verification Evidence
- Confirmed: table rows call `selectItemTarget(...)` only.
- Reproduced at Gate 2 with BUG-286: its bundled `Specification.md` is compiled into the rendered Hub cache and `showProposalSpec(286)` can resolve it, but clicking the BUG row invokes only `selectItemTarget('CRP:286')`; it does not invoke `showProposalSpec(286)`.
- Confirmed: `openOriginalProposalInEditor(...)` explicitly declines to use `Specification.md` as a fallback.
- Reproduced: the in-page Refresh fetches `/proposals` and redraws proposal rows but does not replace `docsCache`; a Zen browser refresh reloads `/hub`, replacing the embedded `RAW_DOCS_CACHE`, which is why it then displayed BUG-286's specification.
- Requirement recorded: a specification edited and saved through `Edit in Notepad++` must render the Hub artifact before completion is reported, but must not force a browser reload.
- Requirement recorded: lifecycle status output must name the attempted action after the first `:`, align header and row columns, and provide an explicit Unblock / ReOpen action for held BUG-287.
- Requirement recorded: the open cohort head is its operational leader. Head actions must route to the complete cohort; non-head member actions remain item-scoped unless the operator explicitly selects the cohort.
- Reproduced during BUG-288 review: Hub status output included raw ANSI sequences, a misaligned formatted table, verbose receipt/baseline internals, and the misleading label `Resolved BCR Cohort (exact)` although the output listed only BUG-288. Review results must distinguish exact individual scope from complete cohort scope and disclose every cohort member.
- Reproduced: selecting Accepted for BUG-288 while open cohort member BUG-287 remained `verified` failed and recommended generic `Complete`, which is not offered by the Hub. The recovery message must name BUG-287 as the blocker and direct the operator to the visible COH-288 review action; **ACCEPTED: COH** is valid only once all members are `in_review`.
- Consolidation decision: the attempted-action text after `:`, lifecycle table alignment, ANSI removal, and accurate Individual/Cohort result rendering are one atomic BUG-287 repair, not separable UI work.
- Consolidation decision: BUG-289's open-cohort visibility finding is part of BUG-287's active cohort repair. COH-288 remained open with BUG-288 and BUG-287 as declared members; BUG-287 completed individually and disappeared from the Hub. It must remain visible until the cohort is resolved, closed, or its membership changes.
- Reproduced after individual review actions: BUG-288 completed independently while COH-288 remained open; BUG-287 remained in_review and its individual acceptance failed because the repository had no remaining committable RHS change. Open cohorts must accept/commit atomically once per repository, then complete every member from the shared receipt.
- Lifecycle state: reinstated to `in_progress` because the required
  specification-first dropdown ordering remains unmet. The repair is now a
  member of COH-275 with CRP-275 as prime; implementation and verification are
  pending.

## 3. Partial Implementation Evidence

- `Show Specification` is now the first actionable item in every proposal
  Lifecycle group. Its compact `${CRP} Lifecycle Actions` heading replaces the
  former two-line item/lifecycle headings, and it is no longer duplicated
  under Documents.
- The daemon now serves the Hub with no-store headers, and existing Hub-window
  refresh uses `Ctrl+F5`, preventing a stale inline artifact from masking the
  corrected menu.
- The wizard now waits for the replacement dropdown after selecting an ITEM,
  so a single click both selects the CRP and opens its action menu.
- BCR action results now retain only the mounted drive, abbreviated base
  commit, and whether the existing `_LCM` window was reused or opened; internal
  baseline kind and metadata-path details are not shown in the status rail.
- Proposal-table cells and the Disposition, Plan State, and Status columns are
  compacted while retaining their labels and values. Evidence is folded out of
  the table and remains available as a proposal-row tooltip. A fixed column
  contract prevents filters and changed values from moving columns.
  Dropdown vertical spacing is reduced, and each menu is a viewport-positioned
  overlay that selects available space above or below its trigger. Browser
  validation confirmed menus remain fully visible rather than being clipped by
  the table pane, and a Plan State filter change preserves every header
  position.
- The full-width work queue preserves page-wide right-edge alignment, and the
  plan-state label folds as `Committed -` followed by `Ready to Push`.
- The default lifecycle rail is now **All**, rather than the restrictive Open
  view. Choosing a Disposition, Plan State, Status, or Priority column filter
  resets any selected lifecycle rail to All, so the requested column value is
  never hidden by an unrelated rail filter.
- All workspace switches dispatch without blocking the Hub, shade and disable
  only their own button while the request is pending, and report success only
  after the refreshed ledger confirms the requested state. Confirmation uses a
  lightweight ledger poll for up to 15 seconds; an unconfirmed command reports
  an explicit error rather than premature success. Each switch uses the
  daemon's direct-script command form, avoiding a redundant nested PowerShell
  startup before persistence begins.
- Formal switch-operation coverage executes the real action script against
  disposable proposal and analysis-state files. It verifies Review,
  Governance, Testing, DOIT, Minimal Tests, and Analysis persistence without
  mutating the live workspace ledger.
- Workspace controls are declarative `workspaceSwitchAtoms`: each atom defines
  its target state, action command, display text, and persisted-state
  confirmation rule. A shared invoker owns dispatch, input locking, timeout,
  refresh, and error reporting, so adding a workspace switch does not duplicate
  asynchronous control-flow code.
- The result counter is positioned between Work Queue and Workspace.
- Priority is shifted left by the widened Actions column, and the wizard
  overlay uses an additional left inset to preserve right-edge clearance.
- The control row, status result, lifecycle rail, panel heading, and selected
  ITEM lifecycle strip are compacted without removing controls; browser
  measurement reclaimed 74px of vertical space above the work-queue table.
- Focused Control Hub safety tests pass 11/11. Remaining BUG-287 components
  remain pending under COH-275.
