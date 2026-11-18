# CRP-192: Compact Inclusion-Scoped Beyond Compare Review

```yaml
CRP-ID: CRP-192
Scope: LCM_Inventory Beyond Compare review preparation
Status: Completed
Plan-State: completed
Progress-State: completed
Maturity: Preliminary design record
Priority: Low
Owner: LCM_Inventory
```

## Problem

The current BCR launcher compares an entire repository baseline to its live working tree. Even with exclusions, a dirty multi-repository workspace can expose unrelated changes and create an unnecessarily broad review surface.

## Proposed Direction

Add an opt-in compact review mode that creates isolated `Baseline` and `Working` trees from an explicit inclusion manifest. The baseline contains the selected files from a chosen Git commit; the working tree contains their current counterparts. Beyond Compare opens only those two trees.

## Current Rebaseline

The goal remains unchanged. Recent review failures confirm that the compact
mode must preserve repository-relative hierarchy, avoid name collisions, and
control stale session windows and filters deterministically. It remains a
future implementation proposal; this review validates the design contract.

## Core Invariants

- Inclusion is explicit; unrelated repository content is absent from the compact trees.
- Each selected file retains its repository root and full repository-relative path beneath `Baseline` and `Working`; flattening paths is prohibited because it can hide ownership and cause name collisions.
- Compact reviews are review-only and do not create a staging manifest, alter Git state, or change live files.
- New files appear only in `Working`; deleted files appear only in `Baseline`.
- The generated manifest records repositories, selected paths, baseline commit(s), and exclusions.
- The existing whole-repository BCR path remains available and unchanged.

## Acceptance Criteria

- An operator can prepare and open a compact BCR session for one CRP or BUG using an explicit file list or manifest.
- The compact session preserves collision-safe repository-relative paths below explicit per-repository roots, including for files with identical names.
- The review artifact clearly distinguishes baseline, working, and new/deleted content.
- The operation does not stage, commit, push, or copy changes back to source repositories.
