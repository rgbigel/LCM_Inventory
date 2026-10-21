# Session Failure Mode Analysis

Module: Invoke-FailureModeAnalysis
Authors: Rolf, Copilot
Version: 10.0.1
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
Optional `-OperationalLogPaths` accepts exact operational log filenames for
literal diagnostic-text corroboration. Missing optional logs are disclosed.

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

The read-only `Invoke-Investigator` stage establishes execution failure before
applying the historical categories. An explicit failed tool result or terminal
nonzero exit status establishes failure. Raw diagnostic text without that status
is placed in **Unresolved evidence**, outside the confirmed-error count.
Git diff hunks, source records, fenced code, and copied diagnostics from known
successful results are not confirmed errors.

Each finding identifies the native event and physical JSONL line, or the exact
task-log line, and includes bounded numbered output context. Output line numbers
are distinct from physical JSONL lines. Runtime stack/location excerpts are
shown only when recorded nearby; neighboring dependency-index records are not
backtraces. Duplicate diagnostic text within one result, and repeated identical
completion records for one call ID, are collapsed; independent calls remain
separate.

Native event timestamps may be shown as recorded event times. Filesystem
modification times and normalized exporter times are never error timestamps.
Generation time remains in the report and its filename.

The execution-flow section includes successful and unknown tool starts as well
as failed executions. It preserves arguments, call/turn/parent IDs, source
citations, the preceding user request and assistant statement, and a recorded
tool argument description (or tool title) when available. Missing stated purpose
is explicit. A completion is
linked only by call ID; a shared turn is labeled separately from chronological
context. Preceding conversation is not proof of why a command ran. No hidden
reasoning, authorization, appropriateness, or causal connection is inferred.

Complementary logs are inspected only when their exact paths are supplied;
there is no cross-session or whole-workspace log hunt. At most three exact-text
matches per log and diagnostic are reported with physical line numbers. Text
matches are marked **execution identity unverified**, not promoted to causes.
No match means no corroboration established, not that no related log exists.

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

Antigravity export times are omitted. Its current exporter may omit call IDs,
result bodies and execution status; these cannot be reconstructed reliably
from chronological proximity. Its task logs belong
to the selected session but cannot necessarily be bounded by the selected
message. Missing bodies and IDE-buffer visibility limit detection. These
limitations are included in the report.
