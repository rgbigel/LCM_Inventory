# Implementation Plan: CRP-277 - Macrium Reflect-Backed BCR Review Workflow

## 1. Executive Summary & Problem Context
The review process needs a reproducible writable baseline and an exact BCR
execution path. Macrium Reflect provides the baseline; Beyond Compare provides
the governed review. This CRP re-implements that complete review workflow.

## 2. Proposed Changes
### Component 1: Macrium Reflect Review Baseline

- Discover eligible restore points from Macrium's same-day completion reports.
  Do not use an older fallback automatically.
- If no completed restore point is found today, start the configured Macrium
  definition and visibly poll until Macrium records completion or the bounded
  timeout expires. Persist one automatic-start receipt per local calendar day;
  a missing backup directory is an availability result that follows this same
  recovery path. Permit an additional same-day backup only through the explicit
  `-ForceNewBackup` operator override.
- Route lifecycle BCR through a mounted-baseline reuse mode. It finds the
  expected volume label in the bounded `F:`-`I:` range and validates `_LCM`
  against that assigned letter, but never detaches, remounts, or replaces the writable
  baseline that records operator review progress.
- Reuse exactly one existing `_LCM` Folder Compare window while the mounted
  baseline is unchanged. Launch it only when absent; refuse duplicate windows
  rather than guessing. Keep the stable `_LCM` title and record each review's
  CRP, BUG, or COH identity in its metadata receipt.
- Keep lifecycle state aligned with review reality: standalone review launch
  transitions a verified CRP to `in_review` only after successful handoff,
  while cohort orchestration remains atomic and records the shared transition
  after all required launches succeed. Acceptance then follows the standard
  authorization, commit, and completion path.
- Gracefully close only the named `_LCM` comparison before cleaning matching
  image mounts in the bounded `F:`-`I:` range.
- Elevate the detach and Browse Image mount operations. Mount only the `D:`
  image partition, accept only a Macrium-selected letter in `F:`-`I:`, enable
  restricted-folder access and writable mode, then validate the expected label
  and `Git_Repositories` root.
- Record mount evidence in the worker receipt: each prior F:-I: drive confirmed
  detached, the reappeared Macrium-selected drive, and snapshot corroboration
  from `ACTIVE_CONTEXT.md` and the GoodNight audit entry. Detach followed by
  reappearance proves replacement; snapshot markers corroborate the selected
  image but do not independently prove its freshness.

### Component 2: Complete BCR Review Execution

- Verify the operator-managed two-way profile binds the mounted
  `Git_Repositories` root to `D:\Git_Repositories`.
- Verify that the profile's saved filters and writable-LHS configuration are
  present without rewriting the profile.
- Resolve the exact CRP, BUG, or declared cohort before BCR; synchronize
  cohort members through their required review gate before opening the
  comparison.
- Reuse an existing exact review window instead of creating duplicate tabs and
  open required cross-repository BCR tabs as separate obligations.
- Record the BCR scope, review disposition, and cross-repository obligations.
  Preserve RHS-only acceptance, staging, commit, and completion behavior.

## 3. Verification Plan
- Test same-day selection, no-older-fallback behavior, bounded polling,
  label-matched mount-root validation within `F:`-`I:`, and `_LCM` profile
  validation.
- Test worker-receipt evidence for confirmed detach, drive reappearance, and
  snapshot corroboration without treating the GoodNight marker alone as proof.
- Test exact-identity BCR resolution, cohort synchronization, session reuse,
  and cross-repository obligation discovery.
- Run focused Pester tests, PowerShell AST parsing, and readiness quality
  gates.
