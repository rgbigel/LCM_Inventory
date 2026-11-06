# Change Request Proposal: CRP-304

```yaml
CRP-ID: CRP-304
Title: Atomized failure analysis report viewer
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: Rolf, Copilot
Date: 2026-10-21 21:55:00
Status: Verified
Plan-State: verified
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Operator selected automatic readable HTML with retained Markdown and -NoLaunch, explicitly requested a dedicated ShowFailureAnalysis tool and atomized sources. Preserve CRP-303 evidence semantics; use small separated report, rendering and interaction components.

## 2. Gate 0 Contract
### Target State
Provide a dedicated, cataloged ShowFailureAnalysis command backed by
tools/Show-FailureAnalysis.ps1. The analyzer produces a readable HTML snapshot
through that viewer, retains its Markdown report and complete structured
evidence, and opens the HTML after successful generation by default.
The viewer can reopen a specific retained report without rerunning analysis.
Following the operator's 2026-10-21 22:02:03 clarification, the viewer must be
served through the existing LCM daemon at http://127.0.0.1:9876, including
its assets and evidence requests. It must never open a file URL or use a
local-file fallback. Backend report files remain retained evidence, not a
browser-facing communication path.
Keep orchestration, report serialization, rendering and browser interaction
in separate, small, single-responsibility components rather than extending
the existing analyzer module into a larger monolith.

### Invariants and Exit Criteria
1. Retain CRP-303 classification, anchor selection, exact source citations,
   trustworthy event timing, execution linkage and lifecycle non-mutation.
2. Write a versioned structured JSON evidence sibling alongside Markdown.
   Both readable outputs derive from the same evidence model. Preserve
   original strings, line breaks, full patch arguments and source identities
   in structured evidence; do not reconstruct evidence by parsing Markdown.
3. ShowFailureAnalysis accepts an exact report path. With no path, it opens
   the newest retained failure-analysis report in the documented report
   directory, clearly identifying the selected snapshot. It never chooses
   another IDE session to analyze or silently reruns collection.
4. Show an overview, confirmed/unresolved counts and a compact execution-flow
   table. Expand individual executions for full request/context, metadata,
   command arguments, output context and source locations.
5. Decode the representation, not the meaning: strings render with their
   original line breaks; patches use diff-style code blocks, commands use
   multiline code blocks and objects use indented JSON. Never globally
   replace literal backslash sequences in actual evidence.
6. Keep long source/argument bodies collapsed by default. No silent evidence
   truncation; show explicit preview/full-detail boundaries and access to the
   complete JSON/Markdown evidence. Escape all evidence inserted into HTML;
   treat tool output as untrusted text, not executable markup or scripts.
7. Preserve the distinction between recorded purpose, preceding conversation,
   authorization and causal linkage. Successful transport is not necessarily
   successful command execution.
8. The analyzer invokes the viewer after saving the evidence. Both commands
   support -NoLaunch for unattended runs/tests. Use the existing interactive
   desktop dispatch mechanism. An opening failure must be explicit and must
   not destroy the successfully generated report.
   If the daemon cannot be recovered, report the opening failure explicitly;
   do not substitute a local-file viewer.
9. Separate command orchestration, serialization/model handling, HTML template,
   styles and browser interactions. Newly introduced production source files
   should be small enough to read independently; target at most 250 lines per
   file, and disclose any necessary exception before implementation. Do not
   split into meaningless fragments just to satisfy a line count.
10. Register command/help/catalog/documentation consistently. Verify actual
    HTML visibility, folding, newlines, escaping, source links, launch/no-launch
    behavior, missing/invalid reports and complete argument preservation.

### Explicit Non-Goals
Do not modify global transcript exporters, rewrite classification, mutate
historical reports, automatically rerun analysis, push, or introduce a generic
Markdown/browser framework. Viewer opening does not certify report freshness
against current workspace state. Snapshot presentation remains separate from
the live-display synchronization work in CRP-305.

## 3. Technical Requirements & Invariants
- Use the existing desktop launcher and LCM display assets/patterns where
  compatible, without inheriting silent dispatch success or stale-state claims.
- Existing Markdown-only reports remain accessible as original evidence;
  where structured evidence is unavailable, disclose that limitation rather
  than guessing a reconstructed execution model.
- Manual source edits required acceptance of this Specification, subsequently
  recorded in section 4. The operator's chosen behavior is recorded above;
  this bundle makes the structural contract explicit. Gate 2 review remains
  required, with no automatic commit or push.

## 4. Acceptance and Implementation Evidence
- Gate 1: the operator accepted implementation with `DOIT 304,305` at
  `2026-10-21T22:03:44+02:00`. The suggested-state header above is retained as
  the proposal's original metadata; this evidence record does not mutate the
  lifecycle ledger.
- Implementation verified: dedicated `ShowFailureAnalysis` command, structured
  evidence siblings, atomized HTML/CSS/JavaScript presentation, HTTP-only daemon
  integration, no-launch handling, producer metadata, persistent viewer audit
  and bounded custom-root behavior are implemented.
- Verification: 34 focused analyzer/viewer Pester tests passed; the parent
  reports 71 combined Pester tests passed. PowerShell AST, JavaScript syntax,
  governed metadata and CRLF/UTF-8 without BOM checks passed.
- Browser evidence: retained snapshot
  `3e793cbafc4343a09dae797d4b50590f` visibly identifies producer
  `Invoke-FailureModeAnalysis.ps1`, version `10.0.1`, and Summary. The earlier
  large snapshot `74e0aa4f78e14a75890c957a272ea2f2` exposed 3,772 folded
  sections and a complete 36,220-character evidence block with actual newlines
  and pre-wrapped layout. The parent verified exact retained Markdown/JSON
  bytes, exclusively port-9876 HTTP resources and no producer polling.
- All newly introduced production components are at most 250 lines. Existing
  analyzer classification and snapshot evidence semantics are preserved.
- Gate 2 remains pending. No lifecycle mutation, review submission, commit or
  push is performed by this documentation finalization. See
  [Walkthrough.md](Walkthrough.md) for the implementation and verification record.
