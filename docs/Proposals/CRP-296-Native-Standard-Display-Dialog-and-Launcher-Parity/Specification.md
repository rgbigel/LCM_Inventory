# Change Request Proposal: CRP-296

```yaml
CRP-ID: CRP-296
Title: Native Standard Display Dialog and Launcher Parity
Scope: WPF and WinForms Show surfaces
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 14:59:30
Status: Superseded
Plan-State: superseded
Progress-State: deferred
Priority: Medium
Dependency: CRP-293 accepted reference; CRP-292 Accepted Common Goal
```

---

## 1. Goal Reference

Implements the Accepted Common Goal in [CRP-292 Specification.md](../CRP-292-Standard-Display-Atom-and-Adoption-Programme/Specification.md).

## 2. Scope

Apply the native equivalent of Standard Display behavior to:

- [Show-LcmActiveLauncher.ps1](../../../tools/Show-LcmActiveLauncher.ps1)
- [Show-HaAuthDialog.ps1](../../../../HaSSD06/tools/subsystem/Show-HaAuthDialog.ps1)
- Any directly coupled WPF/WinForms modal invoked by those named surfaces.

## 3. Requirements

- Match StandardTableDisplay visual hierarchy, typography, semantic colors, and
  border/radius conventions where native controls permit.
- Declare and verify Per-Monitor DPI V2 behavior.
- Route interactive GUI launch through `Invoke-InteractiveDesktop.ps1`; do not
  create background ghost windows.
- Support Escape dismissal, active-monitor placement, explicit planned-action
  preview, and password visibility peek where secrets are entered.
- Enforce one-instance/mutex and disposal rules for any tray/long-running
  native surface affected by the migration.

## 4. Acceptance Criteria

- Dialogs remain usable and unclipped on supported high-DPI and multi-monitor
  configurations.
- Launches reach the operator’s interactive desktop and do not accumulate stale
  windows during tests.
- Cancel/dismiss paths leave no mutation behind.
- Existing native flows remain behaviorally equivalent and have focused launch,
  input, error, and cleanup checks.

## 5. Non-Goals

- No HTML rewrite of WPF/WinForms applications.
- No secret logging, bypass of authentication checks, or change to secret
  storage authority.
- No start before CRP-293 acceptance.
