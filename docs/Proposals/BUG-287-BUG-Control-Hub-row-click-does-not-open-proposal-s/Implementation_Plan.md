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

## 3. Verification Plan
- Add focused Control Hub tests for specification-first navigation and fallback behavior.
- Verify the clicked identity and the opened document path match.
