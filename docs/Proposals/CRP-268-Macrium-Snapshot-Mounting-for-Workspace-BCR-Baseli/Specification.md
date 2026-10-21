# Change Request Proposal: CRP-268

```yaml
CRP-ID: CRP-268
Title: Macrium Snapshot Mounting for Workspace BCR Baselines
Scope: LCM_Inventory
Baseline-Version: 10.0.0
Author: rgbig
Date: 2026-10-13 18:01:13
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Extend the existing normal workspace review session definition with a tool call that selects and mounts the most suitable read-only Macrium D: drive snapshot as the historical baseline for changed-repository Workspace BCRs. Record the snapshot identity, restore point, mount path, scope, and fallback behavior; reuse existing changed-repository review filtering.

## 2. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.
- Invariant 2: A root workspace BCR is non-lifecycle. It must not use a CRP/BUG/COH identity, mutate lifecycle state, or overwrite cohort or repository lifecycle staging manifests.
- Invariant 3: The review must use a dedicated non-lifecycle receipt and a deliberate, exact root-scope review manifest.
- Invariant 4: The historical side must be a read-only Macrium snapshot mount. Local workspace and Git-root baselines are not valid fallbacks.
- Invariant 5: The comparison is limited to repositories changed since the selected historical snapshot.
- Invariant 6: Standard transient and excluded paths, including logs, scratch, and generated temporary review outputs, are non-committable and must be reported separately from reviewable paths.
