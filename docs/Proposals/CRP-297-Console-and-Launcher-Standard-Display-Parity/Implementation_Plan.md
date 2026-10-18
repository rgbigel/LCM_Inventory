# Implementation Plan: CRP-297 - Console and Launcher Standard Display Parity

## 1. Design Steps

1. Classify each named Show surface as console, diagnostic, or launcher and
   record its callers, parameters, and output consumers.
2. Define/reuse a minimal output and progress contract; do not wrap simple
   commands in unnecessary framework code.
3. Migrate tools in behaviorally coherent groups, preserving old output where
   scripts parse it until consumers are updated and tested.
4. Verify desktop dispatch/no-launch behavior separately from console output.

## 2. Verification

- PowerShell AST validation for every changed script.
- Parameter/help and output-transcript regression tests.
- Focused long-running progress/error tests.
- Interactive desktop dispatch and stale-window hygiene tests for launchers.

## 3. Cross-Repository Gate

Changes to [Show-Supervision.ps1](../../../../LCM_Supervision/tools/Show-Supervision.ps1)
remain owned and reviewed in LCM_Supervision; this proposal does not permit an
unreviewed cross-repository mutation.
