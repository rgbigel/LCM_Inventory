# Walkthrough: CRP-354 - Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs

Date: 2026-11-18 15:27:39

## 1. Path taken and issues on the way
- Correction of Specification section 4 / T3: the rendered preview is not only reached through the removed actions; "Show Repo Docs" (Architecture diagrams) uses the same document window. Because the other document items are not part of this CRP (Q1), the preview and the window stay; "Show CRP" does not use them. The window's "Edit in Notepad++" button still opens VS Code (`/open_editor` runs `code -g`); left for a separate decision.
- The existing `executeDaemonCommand` sends `sync: true`; for a newly started Notepad++ the Control Hub would wait until Notepad++ is closed. "Show CRP" therefore sends its own DO call with `sync: false` (fire-and-forget).
- No daemon (Go) change: the existing `/api/action` route runs the command non-elevated with the workspace root as working directory, so relative bundle paths work.
- Scope amendment T5 (labels) added on operator instruction during implementation; "the latter should be 2 - Review" read as the `in_review` label.
- First patch run stopped before writing: one anchor (12-space option line) was a substring of another (14-space); order swapped.

## 2. Verification evidence (2026-11-18 15:27:39)
- JavaScript syntax: the three inline scripts of the template pass `node --check` (the second one is the JSON data block).
- No reference to the removed actions remains (`showProposalSpec|Plan|Walkthrough|Diff`, `show_spec`: 0); 15 references to "Show CRP" / `showProposalBundle`.
- `Show-LcmControl.ps1 -NoLaunch`: "Dashboard rendered cleanly".
- Live: the exact command "Show CRP" builds for CRP-354, sent through the DO (`Elevated: false`), opened the three documents as Notepad++ tabs (window title shows the full Walkthrough path, i.e. relative paths resolved).
- Check of the removed functions (operator request 2026-11-18): the three Show functions only displayed a cached document and offered the editor button; no ledger, log or other side effect. "Show Diff / BC Review" called `tools/Invoke-BeyondCompareReview.ps1`, which no longer exists, so it was already broken. One loss: their fuzzy search by number also found documents of closed legacy items without a recorded `bundle_dir` (163 items; 21 unreferenced bundle folders and 96 flat files remain in `docs/Proposals`); "Show CRP" uses only `bundle_dir`. All open items have a `bundle_dir`.
- Hidden test dependencies found and updated: `tests/ControlHubSafety.Tests.ps1` (row menu order looked for `showProposalSpec`; label "Committed - Ready to Push") and `tests/ProposalLifecycle.Tests.ps1` (label "2 - REVIEW"). Result: `ControlHubSafety` + `ProposalLifecycle` 53 passed, 8 failed; all 8 are pre-existing (3 lifecycle module cases as before; 5 ControlHubSafety cases whose expected texts do not match the committed HEAD template either, test file unchanged since 2026-11-10).
- Operator decision 2026-11-18 on the legacy-document gap: B, history stays unchanged (no fallback search for closed items without `bundle_dir`).
- Not yet clicked in the browser: the button itself (operator live test at Gate 2; refresh the Control Hub page first).