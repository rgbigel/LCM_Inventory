# Change Request Proposal: CRP-294

```yaml
CRP-ID: CRP-294
Title: Read-Only Standard Display Shell and Evidence Migration
Scope: Show-LcmAnalysisViewer, Show-Rules, Show-WorkspaceReadiness, Show-CmdFolderAnalysis
Baseline-Version: 10.2.1
Author: rgbig
Date: 2026-11-08 14:59:30
Status: Superseded
Plan-State: superseded
Progress-State: deferred
Priority: High
Dependency: CRP-293 accepted reference; CRP-292 Accepted Common Goal
```

---

## 1. Goal Reference

Implements the Accepted Common Goal in [CRP-292 Specification.md](../CRP-292-Standard-Display-Atom-and-Adoption-Programme/Specification.md).

## 2. Scope

Migrate the named read-only web display generators to reusable Standard Display
shell and data-interaction atoms after CRP-293 is accepted:

- [Show-LcmAnalysisViewer.ps1](../../../tools/Show-LcmAnalysisViewer.ps1)
- [Show-Rules.ps1](../../../tools/Show-Rules.ps1)
- [Show-WorkspaceReadiness.ps1](../../../tools/Show-WorkspaceReadiness.ps1)
- [Show-CmdFolderAnalysis.ps1](../../../tools/Show-CmdFolderAnalysis.ps1)

## 3. Requirements

- Adopt canonical tokens, typography, theme persistence, provenance, keyboard
  shortcuts, responsive minimum-width safeguards, and desktop dispatch hygiene.
- Use shared, versioned local data/filter/search/match-counter atoms while
  retaining each display's own data model and read-only navigation.
- Maintain strict template/data separation; large data must be fetched or
  injected as a deterministic payload rather than hardcoded into the template.
- Preserve existing information density, print/report features, deep links, and
  supported search semantics until equivalent replacement is validated.

## 4. Acceptance Criteria

- Each migrated display renders with the common shell and its current data.
- Search/filter results and match counts are deterministic and test-covered.
- Theme preference persists across migrated displays.
- F5, Escape, and primary-search shortcuts function without full-page loss of
  state where supported by the display.
- Every generator passes AST/render checks and each display passes focused
  visual, accessibility, and regression tests.

## 5. Non-Goals

- No mutation endpoints or lifecycle actions.
- No change to source data authority.
- No implementation before CRP-293 acceptance.
