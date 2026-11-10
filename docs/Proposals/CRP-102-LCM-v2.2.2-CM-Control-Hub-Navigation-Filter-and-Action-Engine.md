---
Proposal-ID: CRP-102
CR-ID: CR-2026-053
Scope: LCM Platform (.lcm)
Version: 10.2.0
Affected-Repos: [LCM_Inventory, .lcm]
Status: Suggested
Date: 2026-10-13
Author: Rolf, LCM_AI Engine
Target Scope: LCM_Inventory / docs / CM_CONTROL_HUB.html & Show-CmControlHub.ps1
Affected Version Range: 10.0.0 -> 10.0.0
Impacted Repositories: [LCM_Inventory, .lcm]
---

# CRP-102: CM Control Hub Navigation Hardening, Filter Reconciliation, and Action Engine Implementation

## 1. Executive Summary & Intent
Upgrade the Configuration Management (CM) Control Hub (`CM_CONTROL_HUB.html`) to provide seamless bidirectional navigation (dedicated "Back" button), implement active action handlers for dead UI buttons, reconcile proposal lifecycle filter logic (Completed/Pushed state alignment), and standardize universal action controls.

## 2. Defects & Deficiencies Identified
1. **No "Back" Navigation**: Users entering CM Control Hub have no button to return to the calling dashboard; browser back relies on history and can exit the application.
2. **Dead Action Buttons**:
   * *Active CM Log*: No-op (does not open live log modal).
   * *Historical Log Archive*: No-op.
   * *Help / Guide*: Missing or non-functional.
   * *Action Buttons (Show, Print/Save PDF, Edit)*: Incomplete action bindings.
3. **Filter & Metrics Discrepancy**:
   * Metric card indicates 2 completed items, but clicking the card displays 0 items.
   * Lifecycle state ambiguity: `Pushed` state should imply or map to `Completed`.
   * Scope / Repo filter inconsistency ("All" vs "All Repos" dropdown behavior).
   * Missing "All" selector in the Progress column.

## 3. Proposed Enhancements
1. **Dedicated Navigation**: Add standard `[⬅️ Back to Inventory]` button in header and footer.
2. **Full Action Engine**: Implement functional modal viewers for Active CM Log (`cm_activity.log`), Historical Archives, and Help/Legend dialog.
3. **Unified Filter Engine**: Align `Pushed` and `Completed` lifecycle transitions in metric card filters and fix the "All Repos" / "Progress" multi-select dropdowns.


