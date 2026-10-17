# Walkthrough: BUG-287 - [BUG] Control Hub row click does not open proposal specification

## 1. Executive Summary
BUG-287 records the missing specification-first behavior for Control Hub CRP and BUG row clicks.

## 2. Verification Evidence
- Confirmed: table rows call `selectItemTarget(...)` only.
- Reproduced at Gate 2 with BUG-286: its bundled `Specification.md` is compiled into the rendered Hub cache and `showProposalSpec(286)` can resolve it, but clicking the BUG row invokes only `selectItemTarget('CRP:286')`; it does not invoke `showProposalSpec(286)`.
- Confirmed: `openOriginalProposalInEditor(...)` explicitly declines to use `Specification.md` as a fallback.
- Reproduced: the in-page Refresh fetches `/proposals` and redraws proposal rows but does not replace `docsCache`; a Zen browser refresh reloads `/hub`, replacing the embedded `RAW_DOCS_CACHE`, which is why it then displayed BUG-286's specification.
- Lifecycle state: held during the operator-led LCM on-disk review. No implementation or tests have been executed.
