# Session Failure Mode Analysis

Module: Invoke-FailureModeAnalysis
Authors: Rolf, Copilot
Version: 10.0.0
Date: 2026-10-21

## Usage

```powershell
AnalyzeFailures -Number 300
AnalyzeFailures -CRP 300
AnalyzeFailures -MatchText 'review successful and accepted'
AnalyzeFailures
```

The [routine](../tools/Invoke-FailureModeAnalysis.ps1) selects the active
Copilot or Antigravity session using its host environment, not the model name.
It reuses the corresponding transcript exporter under `D:\OneDrive\cmd`.
Copilot's native event results supplement the normalized export, which omits
tool output. Antigravity's selected-session task logs supplement its export.
It never searches another host or substitutes the newest unrelated session.

Use a bare number, without CRP/BUG/COH prefixes. A number selects its latest
explicit conversational reference; quoted text selects the latest matching
user message. Repeated matches are disclosed. With no selector, the full
captured session is analyzed and its last explicit item reference supplies
the lifecycle target. Dates, version numbers, and arbitrary numbers are not
treated as item references. A missing requested anchor stops before writing.

Offline analysis accepts `-TranscriptPath` with normalized JSON/JSONL events
or native Copilot events. Antigravity task logs can be supplied explicitly
through `-TaskLogDirectory`. Use `-h` for all options.

## Report

Each run writes a new
`Catalog-of-Errors-and-Failure-Modes-yyyyMMdd-HHmmss.md` in
[the catalog directory](../../LCM_AI/docs/Optimizations). A same-second filename
collision receives a unique suffix, never an overwrite. `-OutputDirectory`
selects another existing directory. The original catalog is not modified.

Reports identify the routine, version, generation time including seconds and
timezone, source, anchor, evidence boundaries, and Summary. Seven historical
symptom categories and unclassified tool failures are reported with citations
and investigation suggestions. Pattern matches do not prove historical root
causes. Commands or user discussions alone are not classified as tool errors.

The lifecycle section reuses
[Show-LcmFailureDiagnostic.ps1](../tools/Show-LcmFailureDiagnostic.ps1).
Action `do` is the default; `-Action` chooses another supported action.
A valid action is described, never executed. Missing or ambiguous lifecycle
context is reported without suppressing the execution analysis.

The action section captures [Show-Actions.ps1](../tools/Show-Actions.ps1).
These are recent workspace logs, not necessarily related to the conversation.
`-ActionCount` controls the count. Missing optional evidence and zero findings
are report results, not failures; genuine provider, malformed-input, and I/O
errors stop explicitly.

Antigravity export times may not be original event times. Its task logs belong
to the selected session but cannot necessarily be bounded by the selected
message. Missing bodies and IDE-buffer visibility limit detection. These
limitations are included in the report.
