# Implementation Plan: CRP-304 - Atomized failure analysis report viewer

Module: CRP-304 Implementation Plan
Purpose: Record the accepted implementation scope and verified delivery evidence.
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21

## 1. Executive Summary & Problem Context
Operator selected automatic readable HTML with retained Markdown and -NoLaunch, explicitly requested a dedicated ShowFailureAnalysis tool and atomized sources. Preserve CRP-303 evidence semantics; use small separated report, rendering and interaction components.

## 2. Gate 0 Traceability
- Shared evidence serialization and existing analysis semantics: criteria 1-2.
- Viewer selection and readable/foldable presentation: criteria 3-7.
- Desktop dispatch and independent source components: criteria 8-9.
- Operator discovery and end-to-end verification: criterion 10.

## 3. Proposed Changes
1. Extract narrowly scoped report-model/serialization helpers from the current
   report pipeline. Preserve argument objects and raw patch strings.
2. Add a thin Show-FailureAnalysis.ps1 entry point, a focused rendering helper
   and separate HTML/CSS/JavaScript assets. Reuse existing theme and table
   patterns; use native expandable details for large evidence.
3. Wire analyzer JSON/Markdown generation and default viewer opening with
   -NoLaunch, while keeping collection separate from report viewing.
   Deliver the viewer, assets and evidence over existing daemon port 9876 only;
   add no file-URL or daemon-offline local-file fallback. The minimal serving
   route is a prerequisite within this item, not deferred until CRP-305.
4. Register ShowFailureAnalysis, update directly related help/docs and add
   focused tests. Verify rendered content in a browser where available.
5. Stop for exact-item review before starting the next independent increment.

## 4. Verification Plan
- Pester: source/evidence preservation, JSON schema version, multiline patch
  strings versus literal backslash-n, complete large argument round-trip,
  launch/no-launch, report selection and error behavior.
- HTML: untrusted markup remains inert; long bodies collapsed by default;
  overview and exact source citations visible without opening giant code bodies.
- AST, JavaScript syntax and encoding checks on changed components.
- Reuse analyzer/lifecycle focused regressions; hash original reports/ledger
  around analysis/viewing to verify non-mutation.

## 5. Implementation Results
The operator accepted `DOIT 304,305` at
`2026-10-21T22:03:44+02:00`. The accepted CRP-304 work is implemented and its
implementation evidence is verified; Gate 2 is still pending.

1. `modules/FailureModeAnalysis.psm1` retains evidence selection/classification
   and adds versioned JSON evidence plus shared producer identity/version.
   Markdown and JSON are retained together with collision-safe names.
2. `tools/Show-FailureAnalysis.ps1` provides exact/newest report selection,
   immutable snapshot creation, explicit legacy limitations, no-launch behavior,
   structured JSONL audit and host-only summary/detail output.
3. `modules/FailureAnalysisHtml.psm1`, `assets/failure-analysis.css` and
   `assets/failure-analysis.js` separate shell, styling and browser interaction.
   All newly introduced production components remain at most 250 lines.
4. `tools/Invoke-FailureModeAnalysis.ps1` invokes the dedicated viewer after
   retaining reports. The shared `Open-LcmStandardDisplay` helper opens only the
   daemon's `http://127.0.0.1:9876/failure-analysis/<id>/index.html` route.
   Custom snapshot roots require `-NoLaunch` before collection/writes; daemon
   routing is not broadened. Shared HTTP infrastructure remains parent-owned.
5. `Cmd/ShowFailureAnalysis.cmd`, targeted catalog overrides and
   `docs/FailureModeAnalysis.md` document discovery and invocation without
   regenerating the full catalog. The parent owns canonical macro synchronization.

## 6. Verification Results and Handoff
- 34 focused Pester tests passed; the parent reports 71 combined Pester tests
  passed. AST, JavaScript syntax, governed headers and CRLF/no-BOM checks passed.
- Parent browser checks verified visible producer/version and Summary in
  snapshot `3e793cbafc4343a09dae797d4b50590f`.
- Parent browser checks of snapshot `74e0aa4f78e14a75890c957a272ea2f2`
  verified 3,772 collapsed sections, complete 36,220-character evidence,
  real newlines/pre-wrap, no normal-width overflow, exact retained Markdown/JSON
  bytes, exclusively HTTP port-9876 resources and no producer polling.
- Implementation is verified, not Gate-2 accepted. No lifecycle mutation,
  review submission, commit or push is included in this evidence finalization.
