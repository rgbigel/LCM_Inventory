---
Proposal-ID: BUG-120
CR-ID: BUG-120
Scope: LCM / Desktop UI & Document Viewer
Version: 10.2.0
Affected-Repos: [LCM, LCM_Inventory]
Status: COMPLETED
Date: 2026-10-13
Author: rgbig
Target Scope: Show-Rules.ps1, SHOW_RULES.html, and embedded document reader modal
Affected Version Range: 10.0.0 - 10.0.0
Impacted Repositories: [Git_Repositories, LCM_Inventory]
Severity: High
---

# BUG-120 / BUG-120: Show-Rules Read View Missing Standard Display Options and Post-Print Browser Hang

## 1. Defect Description & Discovery Vector
When navigating the **LCM Authoritative Rules Explorer** (`ShowRules` / `Show-Rules.ps1`):
1. **Missing Display Controls in Reader View**:
   - The main rules dashboard features top-level controls (search, column filters, domain dropdown, Light/Dark mode switch, and a **🖨️ Print / Preview** button).
   - However, clicking the **"Read"** action on any rule row opens a full rendered Markdown document viewer.
   - The displayed reader view does **not** inherit or display the standard display options:
     - No Light/Dark mode toggle (standard theme switch).
     - No dedicated Print / PDF export button or toolbar.
2. **Post-Print Browser Lockup / Hang**:
   - When the user presses `Ctrl+P` inside the rendered document view, the Windows/browser print dialog appears and the printout succeeds.
   - Immediately following the printout (upon print dialog dismissal or completion), the **entire browser becomes completely unresponsive / freezes**.
   - The user is forced to kill and reopen the browser from Windows Explorer to restore responsiveness.

## 2. Root Cause Analysis
- **Disconnected Viewer Context**: In `Show-Rules.ps1`, the reader modal or embedded view renders Markdown content in isolation without embedding the shared toolbar controls (such as the Light Mode toggle or the `LcmTablePrintAtom` toolbar).
- **Print Lifecycle Thread Starvation / Focus Lock**: Invoking native `window.print()` / `Ctrl+P` inside a modal dialog container or embedded iframe without decoupling modal overlay listeners or managing the `beforeprint`/`afterprint` lifecycle can cause Chromium/Edge renderer processes to freeze on focus reconciliation or background event loops.

## 3. Remediation Strategy (Proposed)
1. **Harmonize Reader Display Controls**:
   - Equip the rendered file reader view with standard display options:
     - Prominent theme switch (Light / Dark mode synchronization with dashboard preference).
     - Dedicated **🖨️ Print / PDF** action button.
2. **Harden Print Lifecycle**:
   - Implement robust `beforeprint` and `afterprint` event handlers to sanitize DOM state, release modal capture, and prevent UI thread deadlocks during and after printing.
   - Route printing through a sanitized printable view container or `LcmTablePrintAtom` print flow that isolates document styles and safely restores the interactive view post-print.
3. **Automated & Interactive Verification**:
   - Verify opening `ShowRules`, clicking "Read" on a rule (e.g. `ProposalReviewFlowPolicy.md`), toggling Light mode, and triggering Print without inducing browser hangs.

> [!NOTE]
> **Implementation Complete**: Remediated per operator `PROCEED 120` authorization. The reader modal now includes synchronized Light/Dark theme switching, dedicated document printing, and hardened print lifecycle event handlers preventing browser deadlocks.
