# Bug Repair: BUG-288

```yaml
Bug-ID: BUG-288
Title: [BUG] Priority action advances held proposal lifecycle state
Scope: LCM_Inventory
Version: 10.0.0
Author: rgbig
Date: 2026-10-17 20:58:50
Affected-Repos:
  - LCM_Inventory
Severity: Medium
Status: Held
Root-Cause: Invoking the priority action for held BUG-287 updated its priority but also changed its lifecycle state from held to in_progress.
```

---

## 1. Defect and Intent
Changing a proposal priority must not alter lifecycle state, progress state, review hold, or any review obligation.

## 2. Review Hold
This BUG is held while the operator reviews the current LCM status on disk. No lifecycle code has been modified under BUG-288.
