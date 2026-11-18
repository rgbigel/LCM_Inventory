# Implementation Plan: CRP-296 - Native Standard Display Dialog and Launcher Parity

## 1. Design Steps

1. Inventory native controls, launchers, display/session routing, DPI behavior,
   cancellation, and secret-handling paths.
2. Define a small reusable native style/dispatch helper only where current
   surfaces share a true contract.
3. Migrate one dialog at a time and retain its existing behavior until visual
   and launch validation passes.
4. Add stale-window cleanup to test/launch paths without name-based process
   termination.

## 2. Verification

- PowerShell AST validation and focused Pester tests.
- Interactive-session dispatch checks and explicit no-launch/headless tests.
- Manual high-DPI and multi-monitor visual inspection where automation cannot
  prove actual physical-monitor placement.
- Security checks that verify redaction and cancellation preserve state.
