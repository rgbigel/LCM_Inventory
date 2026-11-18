# Specification: CRP-354

Module: docs/Proposals/CRP-354-Show-CRP-Opens-All-Bundle-Documents-In-Notepad-Plu/Specification CRP-354.md
Purpose: Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs
Path: LCM_Inventory/docs/Proposals/CRP-354-Show-CRP-Opens-All-Bundle-Documents-In-Notepad-Plu/Specification CRP-354.md
Authors: Rolf, Claude
Version: 10.7.4
Status: Suggested
Date: 2026-11-18 20:51:16

```yaml
CRP-ID: CRP-354
Title: Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-18 20:51:16
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: 5
App-ID: None
```

---

## 1. Executive Summary & Intent
- Specification accepted by the operator on 2026-11-18 15:24:00 (Gate 1, 'ACCEPT 354 specification, do it').
Reviewing a CRP from the Control Hub takes several dropdown actions, one document at a time. One action, "Show CRP", opens all three bundle documents at once as tabs in Notepad++, which notices when a file changes later. The single-document actions go away.
- Review: this Specification and the Walkthrough (one correction of section 4: the rendered preview stays, because "Show Repo Docs" also uses it). Scope amendment: three plan-state labels shortened (T5).
- Revision 2 (operator Gate 2 2026-11-18, "accepted with changes"): the rendered preview and the other document actions stay; their editor button opens Notepad++ in the foreground (T6); "Edit Original CRP" is removed (Q3). Review: the Walkthrough sections 3 and 4.

## 2. Gate 0 Contract
### Target State
- T1: the top item of the CRP row's wizard (🧙) dropdown reads "Show CRP". One click opens `Specification.md`, `Implementation_Plan.md` and `Walkthrough.md` of that item as three tabs, in this order, in one Notepad++ window, in the foreground.
- T2: the same "Show CRP" replaces "Show Specification" everywhere it appears: the CRP row dropdown (top and in its Documents section), the cohort row dropdown (opens the head item's documents), the ACTIONS select of the control row, and the per-item select of the bulk panel.
- T3: the actions "Show Specification", "Show Plan", "Show Walkthrough" and "Show Diff / BC Review" are removed with their functions. The in-browser rendered preview (Mermaid diagrams, images) stays (operator 2026-11-18): it is the basis for a later viewer that shows the three documents of an item side by side, and it serves the other document actions.
- T5 (scope amendment, operator 2026-11-18 during implementation): the plan-state labels of the Control Hub read "Committed" (was "Committed - Ready to Push"), "Verified" (was "Verified: ready for 2 - REVIEW") and "2 - Review" (was "2 - REVIEW").
- T4: the DO daemon starts Notepad++ itself, directly and non-elevated (CRP-343 border rule); no detour through VS Code (`code`), which would open another VS Code window. A missing document is skipped and named in a toast, not an error.
- T6: every editor button of the Control Hub ("Show CRP", "Edit in Notepad++" of the document window, activity log) opens its file(s) in Notepad++ through the DO and brings Notepad++ to the foreground (`tools/Open-LcmNotepadPlusPlus.ps1` with the AHK atom `activate-window`).

### Invariants and Exit Criteria
- The other document actions (Show Repo Docs, Show Review Receipt, Show State History) stay; only their editor button is redirected (T6). No other dropdown action changes.
- Opening a document never starts an additional VS Code window.
- Exit: from a CRP row, "Show CRP" opens the three tabs with Notepad++ in the foreground; editing one file outside Notepad++ makes Notepad++ offer to reload it; the removed actions no longer appear in any of the four places; "Edit in Notepad++" opens Notepad++, not VS Code.

### Explicit Non-Goals
- Lifecycle, cohort, FIX and terminal-disposition actions of the dropdown.
- Notepad++ settings: file status auto-detection is a Notepad++ option (on by default); the CRP does not change it.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Decided Points (operator 2026-11-18)
- Q1: the other document items are not part of this CRP; "Show Diff / BC Review" is removed (never used; BCR is the review path).
- Q2: "Show CRP" shows the documents as plain text in Notepad++. BCR, the review tool, also shows each document as plain text. The rendered preview stays for the other document actions (T3).
- Q3 (operator Gate 2 2026-11-18): "Edit Original CRP" is removed; a bundle holds only "Specification <ID>.md", so there is no original CRP.
## Absorbed Operator Remarks

> backcheck: the notepad++ call should be direct DO, not use VSCode (that creates another VSCode window)
> Q1: other doc items are not part of this crp, and Show Diff is purely within the VSCode, but i have never used it yet, so delete them
> Q2: This probably only affects the Specification.md, but all three should be open in VSCode Editor anyway (but unfortunately, often it's not working when using Claude code, it works in Antigravity) . Normally, changed items are open in the editors of VSCode? So the answer to Q2 is: Show the items as plain text. (The review tool is still BCR, which also can display each item as plain text only)

(Operator, 2026-11-18; source of T3, T4 and section 3.)

> in lcm control hub (showCM) the plan state "Committed - Ready to Push" is too long, shorten to "Committed"
> same for "Verified..."
> the latter should be "2 - Review"

(Operator, 2026-11-18, during the CRP-354 implementation; source of T5. Read as: the in_review label becomes "2 - Review"; "Verified" stays.)

> spec 354:
> T4 removing mermaid diagrams is a bit harsh do, so not do that.
> two reasons: they could be a tool that shows  the "tabs" for three docs which are in close context, replacing notepad++. Obidian? Also, without any change, i can open a specification inside the running Claude (VSCode) session as well.
> Invariants: i think it would be no extra effort to remove the item "Edit original CRP" right here, Mention as Q3. The others you mentioned  in invariant are not to be deleted at all! (as long as you do not open additional VSCode sessions, adjust the calls. so, ##4 is not what i want. I do not get why you call it a discrepancy, the goal is clear: see absorved remarks
> Accepted with changes

> opening editor should put it into the foregroud

(Operator, 2026-11-18, Gate 2 of revision 2; source of T3 (preview stays), T6, Q3 and the removal of the former section 4.)