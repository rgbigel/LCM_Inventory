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
