# Change Request Proposal: CRP-303

```yaml
CRP-ID: CRP-303
Title: Unified session error catalog and lifecycle action diagnostics
Scope: LCM_Inventory
Baseline-Version: 10.0.1
Author: Rolf, Copilot
Date: 2026-10-21 18:28:34
Status: In Review
Plan-State: in_review
Progress-State: verification
Priority: High
App-ID: None
```

---

## 1. Executive Summary & Intent
Reconstruct an evidence-based, active-host-specific failure-mode report from the historical catalog. Accept a bare item number or quoted conversation anchor, default to the last referenced item, combine read-only lifecycle diagnostics and Show-Actions output, and write a timestamped sibling report identifying generator name/version and including a Summary. Preserve original catalog and all lifecycle state.

Specification accepted by Rolf on 2026-10-21 at 18:54:34 +02:00
("option 1": accept and implement to the review checkpoint).

## 2. Gate 0 Contract
### Target State
Provide `Invoke-FailureModeAnalysis.ps1` in `LCM_Inventory/tools`, with a
cataloged command `AnalyzeFailures`. It reconstructs a repeatable, evidence-based
analysis of the error patterns documented in the historical catalog, adds
read-only lifecycle diagnostics and recent action-log evidence, and writes a
new report beside the original:

`LCM_AI/docs/Optimizations/Catalog-of-Errors-and-Failure-Modes-yyyyMMdd-HHmmss.md`

Every report identifies the generator name, generator version, generation date
and time through seconds (with timezone), source host/session, selected anchor,
and evidence boundaries. A Summary reports findings, lifecycle diagnostic
status, available action evidence, and coverage limitations.

### Invariants and Exit Criteria
1. Support both Copilot and Antigravity through the existing host-specific
   transcript providers. Choose by active host/session identity, not model name.
   Never read the inactive host or substitute an unrelated recent session.
2. Accept a bare item number (`-Number 300`, alias `-CRP 300`) or literal user-input
   text (`-From "quoted input"`, alias `-MatchText`). Neither BUG nor COH prefixes
   are required from the operator.
3. A number selects its latest explicit conversation reference; quoted text
   selects its latest matching user message. Analyze from that boundary through
   the end of the captured session, excluding the current analysis invocation
   when identifiable. Disclose repeated matches and the selected event.
4. Without a supplied number, use the last explicitly referenced item number in
   the selected conversation evidence. Do not infer an item from arbitrary
   timestamps, version strings, or unrelated numeric values. Where no item is
   identifiable, still report execution/action evidence and mark lifecycle
   diagnostics unavailable.
5. A missing explicitly requested number/text anchor stops before report
   creation. Valid lifecycle actions, zero detected errors, missing optional
   action logs, and unresolved/ambiguous lifecycle context are report outcomes,
   not terminating failures. Real provider, malformed-input, tool, or I/O errors
   remain explicit.
6. Resolve number-only item references against current proposal/cohort records.
   Report multiple applicable identities rather than guessing a CRP, BUG, or COH
   kind. Any lifecycle diagnostic must use an exact resolved proposal identity;
   cohorts may be described with their declared members.
7. Default lifecycle action is `do`. Reuse the canonical lifecycle action
   validation and failure report used by `Show-LcmFailureDiagnostic.ps1`.
   A valid action is reported as valid and is NEVER applied. Preserve the
   existing standalone command's refusal of valid actions.
8. Include `Show-Actions.ps1` evidence with provenance and collection time.
   Clearly distinguish recent workspace action logs from session-scoped
   evidence; do not imply unrelated logs caused the selected failure.
9. Cover all seven historical categories: stripped pipeline variable, stripped
   assignment, uninitialized variable, locked file, elevation/permission
   failure, repeated tool prefix, and IDE diff/buffer overwrite symptoms.
   Include unknown tool failures as unclassified, not as a successful scan.
10. Findings cite source events/files and observed evidence. Historical
    explanations are hypotheses/countermeasures, not verified causes of every
    new matching symptom. Never classify quoted commands, the old catalog,
    or user discussion alone as confirmed tool failures.
11. Preserve the original catalog byte-for-byte and never overwrite an existing
    timestamped report, including two runs within one second. Write reports as
    UTF-8 without BOM with CRLF line endings.
12. Provide focused tests for both providers, anchors, lifecycle behavior,
    category detection, summary/metadata shape, non-mutation, and output
    collision safety. Wire usage help, tool catalog, and command trampoline.

### Explicit Non-Goals
Do not recreate an undocumented historical generator exactly, fabricate root
causes, apply lifecycle transitions, alter global host exporters, fix unrelated
governance issues, commit, or push. Preserve unrelated in-progress changes.

## 3. Technical Requirements & Invariants
- Existing source catalog:
  [Catalog-of-Errors-and-Failure-Modes.md](../../../../LCM_AI/docs/Optimizations/Catalog-of-Errors-and-Failure-Modes.md).
- Existing host exporters: `D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1`
  and `D:\OneDrive\cmd\Export-AntigravityReasoningTranscript.ps1`.
- Existing diagnostic surfaces:
  [Show-LcmFailureDiagnostic.ps1](../../../tools/Show-LcmFailureDiagnostic.ps1),
  [Show-Actions.ps1](../../../tools/Show-Actions.ps1), and
  [ProposalManager.psm1](../../../modules/ProposalManager.psm1).
- Keep any shared extraction narrowly scoped; do not introduce a competing
  lifecycle authority or a second host-transcript storage format.
