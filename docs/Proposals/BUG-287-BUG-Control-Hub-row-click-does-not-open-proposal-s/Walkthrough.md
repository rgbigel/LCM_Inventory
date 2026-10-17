# Walkthrough: BUG-287 - [BUG] Control Hub row click does not open proposal specification

## 1. Executive Summary
BUG-287 records the missing specification-first behavior for Control Hub CRP and BUG row clicks.

## 2. Verification Evidence
- Confirmed: table rows call `selectItemTarget(...)` only.
- Reproduced at Gate 2 with BUG-286: its bundled `Specification.md` is compiled into the rendered Hub cache and `showProposalSpec(286)` can resolve it, but clicking the BUG row invokes only `selectItemTarget('CRP:286')`; it does not invoke `showProposalSpec(286)`.
- Confirmed: `openOriginalProposalInEditor(...)` explicitly declines to use `Specification.md` as a fallback.
- Reproduced: the in-page Refresh fetches `/proposals` and redraws proposal rows but does not replace `docsCache`; a Zen browser refresh reloads `/hub`, replacing the embedded `RAW_DOCS_CACHE`, which is why it then displayed BUG-286's specification.
- Requirement recorded: a specification edited and saved through `Edit in Notepad++` must render the Hub artifact before completion is reported, but must not force a browser reload.
- Requirement recorded: lifecycle status output must name the attempted action after the first `:`, align header and row columns, and provide an explicit Unblock / ReOpen action for held BUG-287.
- Requirement recorded: the open cohort head is its operational leader. Head actions must route to the complete cohort; non-head member actions remain item-scoped unless the operator explicitly selects the cohort.
- Reproduced during BUG-288 review: Hub status output included raw ANSI sequences, a misaligned formatted table, verbose receipt/baseline internals, and the misleading label `Resolved BCR Cohort (exact)` although the output listed only BUG-288. Review results must distinguish exact individual scope from complete cohort scope and disclose every cohort member.
- Reproduced: selecting Accepted for BUG-288 while open cohort member BUG-287 remained `verified` failed and recommended generic `Complete`, which is not offered by the Hub. The recovery message must name BUG-287 as the blocker and direct the operator to the visible COH-288 review action; **ACCEPTED: COH** is valid only once all members are `in_review`.
- Consolidation decision: the attempted-action text after `:`, lifecycle table alignment, ANSI removal, and accurate Individual/Cohort result rendering are one atomic BUG-287 repair, not separable UI work.
- Consolidation decision: BUG-289's open-cohort visibility finding is part of BUG-287's active cohort repair. COH-288 remained open with BUG-288 and BUG-287 as declared members; BUG-287 completed individually and disappeared from the Hub. It must remain visible until the cohort is resolved, closed, or its membership changes.
- Lifecycle state: held during the operator-led LCM on-disk review. No implementation or tests have been executed.
