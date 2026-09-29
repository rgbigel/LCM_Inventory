# CRP-192: Compact Inclusion-Scoped Beyond Compare Review

```yaml
CRP-ID: CRP-192
Scope: Workspace_Inventory Beyond Compare review preparation
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: Low
Owner: Workspace_Inventory
```

## Problem

The current BCR launcher compares an entire repository baseline to its live working tree. Even with exclusions, a dirty multi-repository workspace can expose unrelated changes and create an unnecessarily broad review surface.

## Proposed Direction

Add an opt-in compact review mode that creates isolated `Baseline` and `Working` trees from an explicit inclusion manifest. The baseline contains the selected files from a chosen Git commit; the working tree contains their current counterparts. Beyond Compare opens only those two trees.

## Core Invariants

- Inclusion is explicit; unrelated repository content is absent from the compact trees.
- Compact reviews are review-only and do not create a staging manifest, alter Git state, or change live files.
- New files appear only in `Working`; deleted files appear only in `Baseline`.
- The generated manifest records repositories, selected paths, baseline commit(s), and exclusions.
- The existing whole-repository BCR path remains available and unchanged.

## Acceptance Criteria

- An operator can prepare and open a compact BCR session for one CRP or BUG using an explicit file list or manifest.
- The compact session preserves repository-relative paths below per-repository roots.
- The review artifact clearly distinguishes baseline, working, and new/deleted content.
- The operation does not stage, commit, push, or copy changes back to source repositories.
