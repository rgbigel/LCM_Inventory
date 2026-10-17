# Implementation Plan: BUG-287 - [BUG] Control Hub row click does not open proposal specification

## 1. Executive Summary & Problem Context
BUG-287 captures the Control Hub document-navigation defect for review; implementation is held.

## 2. Proposed Changes
### Component 1: Specification-first row navigation
- Make a CRP/BUG row click open its bundled `Specification.md`.
- Fall back to the original CRP editor only if the specification cannot be resolved.
- Preserve explicit action-menu item selection behavior and prevent accidental actions from row clicks.
- Place `Show Specification` as the first proposal drop-down action, before the Lifecycle group and all state-changing actions.

### Component 2: Refresh document content consistently
- Ensure the in-page Refresh updates the compiled document cache used by `Show Specification`, or clearly states that a browser reload is required.
- Verify that an updated specification is visible after in-page Refresh without relying on a separate browser refresh.
- On an `Edit in Notepad++` document save, render the backend Hub artifact before reporting the save outcome, without sending a browser reload event.

### Component 3: Make lifecycle feedback actionable
- Format status output as `<result>: <attempted action>` before the lifecycle table.
- Use one shared column-width contract for lifecycle table headers and rows.
- Render an explicit **Unblock / ReOpen** action for held CRP/BUG items and verify that it resumes the correct exact item.

### Component 4: Route head actions to the cohort
- Resolve a lifecycle action issued on an open cohort head to that cohort's complete membership.
- Keep non-head member actions item-scoped unless the operator explicitly chooses the cohort.
- Add focused tests showing that a head action advances members together or stops the cohort at the first unavailable common gate.

### Component 5: Render review results for the Hub
- Strip ANSI sequences before displaying tool output in the Hub.
- Render a compact scope/action/result summary first; place receipts and baseline metadata in a collapsible detail section.
- Validate that Cohort results enumerate all declared members and that Individual results do not claim cohort resolution.
- Map every blocked acceptance error to an action currently visible for the exact item or its open cohort; for an incomplete cohort, name the blocking member and offer **Open Review COH-<head>**, not generic Complete.
- Enable **ACCEPTED: COH** only when every declared member is `in_review`.
- Implement this component atomically with Component 3: the `: <attempted action>` status text, header/row alignment, ANSI removal, and accurate scope rendering are one operator-facing repair and must be validated together.

### Component 6: Preserve open cohort membership visibility
- Render every declared member of an open cohort without filtering by individual proposal state.
- Display each member's state, gate status, and blocking/completion outcome.
- Verify that individually completed, blocked, and in-review members remain visible until explicit cohort resolution, closure, or membership change.

## 3. Verification Plan
- Add focused Control Hub tests for specification-first navigation and fallback behavior.
- Verify the clicked identity and the opened document path match.
