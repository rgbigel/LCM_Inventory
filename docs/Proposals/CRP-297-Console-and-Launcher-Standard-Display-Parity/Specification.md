# Change Request Proposal: CRP-297

```yaml
CRP-ID: CRP-297
Title: Console and Launcher Standard Display Parity
Scope: Console, diagnostic, and launcher Show surfaces
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

Assess and standardize the console/launcher family, including:

- [Show-Actions.ps1](../../../tools/Show-Actions.ps1)
- [Show-HaInventory.ps1](../../../tools/Show-HaInventory.ps1)
- [Show-LastLog.ps1](../../../tools/Show-LastLog.ps1)
- [Show-LcmDaemon.ps1](../../../tools/Show-LcmDaemon.ps1)
- [Show-LcmFailureDiagnostic.ps1](../../../tools/Show-LcmFailureDiagnostic.ps1)
- [Show-Repos.ps1](../../../tools/Show-Repos.ps1)
- [Show-SuperController.ps1](../../../tools/Show-SuperController.ps1)
- [Show-ToolIndex.ps1](../../../tools/Show-ToolIndex.ps1)
- [Show-Supervision.ps1](../../../../LCM_Supervision/tools/Show-Supervision.ps1)

## 3. Requirements

- Standardize structured ASCII/ANSI status tags: `[INFO]`, `[WARN]`, `[ERROR]`,
  `[ACTION]`, and `[SUMMARY]`.
- Use the shared progress atom for long-running operations without clobbering
  diagnostics or falsely reporting completion.
- Present normalized tool/runtime provenance and explicit failure reasons.
- Ensure web/native launchers use the appropriate interactive-desktop route and
  respect `-NoLaunch`/headless test behavior.
- Preserve every supported parameter, output contract, and automation caller
  unless a separately accepted compatibility change states otherwise.

## 4. Acceptance Criteria

- Each in-scope tool has deterministic success, warning, error, and summary
  output suited to its operation.
- Long-running output remains readable and preserves error evidence.
- Launchers do not create hidden/duplicate GUI windows and honor no-launch
  testing paths.
- Focused transcript, parameter, AST, and launch behavior tests pass.

## 5. Non-Goals

- No conversion of consoles into browser dashboards.
- No reclassification of tools that are intentionally simple launchers.
- No start before CRP-293 acceptance.
