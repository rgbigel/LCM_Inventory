# Bug Repair: BUG-287

```yaml
Bug-ID: BUG-287
Title: [BUG] Control Hub row click does not open proposal specification
Scope: LCM_Inventory
Version: 10.0.0
Author: rgbig
Date: 2026-10-17 20:49:32
Affected-Repos:
  - LCM_Inventory
Severity: Medium
Status: Held
Root-Cause: Proposal-row clicks select only the active item target. The available original-source action rejects Specification.md as a fallback, leaving the expected primary proposal document unopened.
```

---

## 1. Defect and Intent
Clicking a CRP or BUG must open its `Specification.md`, including an item currently visible at Gate 2. Only when that bundle document is unavailable may the Hub fall back to editing the original CRP source.

## 2. Review Hold
This BUG is deliberately held while the operator reviews the current LCM status on disk. No UI behavior has been modified under BUG-287.

## 3. Low-Priority Menu Ordering Requirement
When this held BUG is implemented, `Show Specification` must be the first action in the proposal drop-down. It is the normal first step before any lifecycle action such as `Proceed`, review opening, or completion.

## 4. Document Refresh Consistency
The in-page Refresh action must refresh the compiled proposal-document cache, or explicitly report that document content remains stale. It must not appear equivalent to a browser refresh while updating only proposal rows.

An operator save made through `Edit in Notepad++` must trigger the same backend Hub-artifact render as a managed document update. It must not force a browser reload; the operator retains control of that refresh.

## 5. Lifecycle Status Output and Held-Item Recovery
Lifecycle status output must identify the action attempted immediately after its first `:`. The table header and every rendered data column must remain visibly aligned. A held BUG must expose an explicit **Unblock / ReOpen** action so an operator can resume it without inferring a hidden lifecycle command.

## 6. Cohort Head Leadership
The head of an open cohort is its operational leader. A lifecycle action selected on the head must operate on the entire open cohort by default and stop at the first member that cannot reach the common required gate. An action on a non-head member must remain item-scoped unless the operator explicitly selects the cohort target.

## 7. Readable Review Result Contract
Hub status/action output must remove ANSI terminal escape sequences and present a concise action summary before optional technical detail. A review result must identify its actual scope as either **Individual** or **Cohort**. A cohort result must list every declared member and each member's gate outcome; an individual result must never be labelled “BCR Cohort”.

When an acceptance cannot proceed because an open cohort member has not reached `in_review`, the failure must identify that member and direct the operator to the currently visible cohort action, for example **Open Review COH-288**. It must not recommend an unavailable generic `Complete` action. **ACCEPTED: COH** must be the offered and enabled acceptance action only after every cohort member reaches `in_review`.

## 8. Open Cohort Member Visibility
Every declared member of an open cohort must remain visible regardless of individual state. A completed, failed, held, or rejected member must display its current state and outcome until the cohort is explicitly resolved, closed, or its membership changes.
