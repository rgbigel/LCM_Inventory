# Specification: CRP-354

Module: docs/Proposals/CRP-354-Show-CRP-Opens-All-Bundle-Documents-In-Notepad-Plu/Specification.md
Purpose: Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs
Path: LCM_Inventory/docs/Proposals/CRP-354-Show-CRP-Opens-All-Bundle-Documents-In-Notepad-Plu/Specification.md
Authors: Rolf, Claude
Version: 10.7.4
Status: Suggested
Date: 2026-11-18 15:27:39

```yaml
CRP-ID: CRP-354
Title: Show CRP Opens All Bundle Documents In Notepad Plus Plus Tabs
Scope: LCM_Inventory
Baseline-Version: 10.7.4
Author: Rolf, Claude
Date: 2026-11-18 15:27:39
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

## 2. Gate 0 Contract
### Target State
- T1: the top item of the CRP row's wizard (🧙) dropdown reads "Show CRP". One click opens `Specification.md`, `Implementation_Plan.md` and `Walkthrough.md` of that item as three tabs, in this order, in one Notepad++ window, in the foreground.
- T2: the same "Show CRP" replaces "Show Specification" everywhere it appears: the CRP row dropdown (top and in its Documents section), the cohort row dropdown (opens the head item's documents), the ACTIONS select of the control row, and the per-item select of the bulk panel.
- T3: the actions "Show Specification", "Show Plan", "Show Walkthrough" and "Show Diff / BC Review" are removed, together with their functions and the in-browser rendered preview (Mermaid diagrams, images) that only they open.
- T5 (scope amendment, operator 2026-11-18 during implementation): the plan-state labels of the Control Hub read "Committed" (was "Committed - Ready to Push"), "Verified" (was "Verified: ready for 2 - REVIEW") and "2 - Review" (was "2 - REVIEW").
- T4: the DO daemon starts `notepad++.exe` itself, directly and non-elevated (CRP-343 border rule); no detour through VS Code (`code`), which would open another VS Code window. A missing document is skipped and named in a toast, not an error.

### Invariants and Exit Criteria
- No other dropdown action changes; the other document items (Edit Original CRP, Show Repo Docs, Show Review Receipt, Show State History) are not part of this CRP.
- Exit: from a CRP row, "Show CRP" opens the three tabs; editing one file outside Notepad++ makes Notepad++ offer to reload it; the three removed actions no longer appear in any of the four places.

### Explicit Non-Goals
- Lifecycle, cohort, FIX and terminal-disposition actions of the dropdown.
- Notepad++ settings: file status auto-detection is a Notepad++ option (on by default); the CRP does not change it.
- Default Non-Goal: Cause no havoc; ask rather than invent or infer, and avoid unnecessary complexity.

## 3. Decided Points (operator 2026-11-18)
- Q1: the other document items are not part of this CRP; "Show Diff / BC Review" is removed (never used; BCR is the review path).
- Q2: documents are shown as plain text only; the rendered preview is dropped. BCR, the review tool, also shows each document as plain text.
## 4. Discrepancy Found
- The preview window's button "Edit in Notepad++" actually opens VS Code: the daemon's `/open_editor` runs `code -g <file>`. With T3 the preview window and this button are removed; T4 adds the direct Notepad++ launch. Whether `/open_editor` keeps its VS Code mode for other callers is decided at implementation (only the Control Hub calls it).

## Absorbed Operator Remarks

> backcheck: the notepad++ call should be direct DO, not use VSCode (that creates another VSCode window)
> Q1: other doc items are not part of this crp, and Show Diff is purely within the VSCode, but i have never used it yet, so delete them
> Q2: This probably only affects the Specification.md, but all three should be open in VSCode Editor anyway (but unfortunately, often it's not working when using Claude code, it works in Antigravity) . Normally, changed items are open in the editors of VSCode? So the answer to Q2 is: Show the items as plain text. (The review tool is still BCR, which also can display each item as plain text only)

(Operator, 2026-11-18; source of T3, T4 and section 3.)

> in lcm control hub (showCM) the plan state "Committed - Ready to Push" is too long, shorten to "Committed"
> same for "Verified..."
> the latter should be "2 - Review"

(Operator, 2026-11-18, during the CRP-354 implementation; source of T5. Read as: the in_review label becomes "2 - Review"; "Verified" stays.)
