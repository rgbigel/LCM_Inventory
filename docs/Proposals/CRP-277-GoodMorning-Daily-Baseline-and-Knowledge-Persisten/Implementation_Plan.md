# Implementation Plan: CRP-277 - GoodMorning Daily Baseline and Knowledge Persistence Routine

## 1. Executive Summary & Problem Context
GoodMorning needs a repeatable daily preparation path for the Macrium-backed
Beyond Compare LHS baseline. GoodNIGHT receipt/recovery work is separated into
CRP-278.

## 2. Proposed Changes
### Component 1: Daily Macrium Baseline Provisioning

- Extend, rather than replace, the existing read-only
  `Invoke-WorkspaceGoodMorning.ps1` session recovery report with an explicit
  `-PrepareBcrBaseline` opt-in.
- Discover eligible restore points from Macrium's same-day completion reports.
  Do not use an older fallback automatically.
- If no completed restore point is found today, start the configured Macrium
  definition and visibly poll until Macrium records completion or the bounded
  timeout expires.
- Gracefully close only the named `_LCM` comparison before cleaning matching
  image mounts in the bounded `F:`-`I:` range.
- Elevate the detach and Browse Image mount operations. Mount only the `D:`
  image partition, require the configured `F:` assignment rather than silently
  accepting an alternate, enable restricted-folder access and writable mode,
  then validate the expected label and `Git_Repositories` root.
- Validate the existing `_LCM` profile's exact roots, content comparison,
  changed-only directory handling, `.git\hooks` inclusion, and writable-LHS
  contract before launch. Do not rewrite its filters or settings.
- Resolve an active CRP/BUG as the explicit RHS review scope and record it in
  the execution receipt. When none exists, record `BCR-BASELINE-DUMMY` without
  creating lifecycle evidence.

### Component 2: Beyond Compare Readiness

- Verify the operator-managed two-way profile binds the mounted
  `Git_Repositories` root to `D:\Git_Repositories`.
- Verify that the profile's saved filters and writable-LHS configuration are
  present without rewriting the profile.
- Preserve the RHS-only lifecycle acceptance rule.

## 3. Verification Plan
- Test today-only backup selection, no-older-fallback behavior, cancellation,
  and timeout reporting with mocked Macrium discovery.
- Test mount-root, drive-letter, and BC-profile validation failures.
- Run focused Pester tests, PowerShell AST parsing, and readiness quality
  gates.
