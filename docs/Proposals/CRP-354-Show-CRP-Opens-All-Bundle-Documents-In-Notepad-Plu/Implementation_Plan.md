# Implementation Plan: CRP-354 - Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs

Date: 2026-11-18 15:27:39

## Changes in `assets/CM_CONTROL_HUB.html` (template 10.2.4 -> 10.2.5)
- New `showProposalBundle(id)`: builds `"C:\Program Files\Notepad++\notepad++.exe" "<repo>\<bundle_dir>\Specification.md" "...\Implementation_Plan.md" "...\Walkthrough.md"` (relative paths; the daemon runs commands with the workspace root as working directory) and posts it to `/api/action` as a DO call with `sync: false`; documents missing from the cache are skipped and named in a toast.
- "Show CRP" replaces "Show Specification" in: CRP row dropdown (top item and Documents section), cohort row dropdown (head item), ACTIONS select (`show_crp`), bulk-panel select.
- Removed: menu items "Show Plan", "Show Walkthrough", "Show Diff / BC Review"; functions `showProposalSpec`, `showProposalPlan`, `showProposalWalkthrough`, `showProposalDiff`.
- Labels (T5): `in_review` "2 - Review", `verified` "Verified", `completed` "Committed".
- Unchanged (not part of this CRP, Q1): Edit Original CRP, Show Repo Docs, Show Review Receipt, Show State History, the document window with its rendered preview and its "Edit in Notepad++" button (which still opens VS Code).