# CRP-257: Evidence-Based Reasoning Analysis

| Metadata Field | Value |
|---|---|
| Proposal ID | `CRP-257` |
| Lifecycle State | `IN_PROGRESS` (`DOIT`) |
| Target Scope | `LCM_Inventory` toolchain and `D:\OneDrive\cmd` command wrappers |
| Affected Version Range | `Invoke-ReasoningAnalysis` v1.0.0 to v2.0.0 |
| Impacted Repositories | `LCM_Inventory`, `LCM_AI` |
| Priority | `10` |

## Problem

The reasoning-analysis command has stale global wrappers, misleading invocation guidance,
and generates static content rather than analyzing an actual chat transcript. Numeric turn
offsets are unstable and do not let an operator select a requested analysis boundary by
quoting the relevant chat input.

## Requirements

1. Keep the canonical global command wrappers under `D:\OneDrive\cmd`.
2. Ensure both global wrappers and the repository trampoline invoke the same canonical script.
3. Add `ar`, `AnalyzeReasoning`, and `ReasoningAnalysis` command aliases.
4. Active-Host-Only Automatic Transcript Provider: When the operator enters
   `ar -From "<quoted chat input>" [-Until "<quoted chat input>"]` (or aliases `AnalyzeReasoning`, `ReasoningAnalysis`),
   the command dispatcher (`D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1`) identifies the single active host:
   - In Antigravity: invokes `D:\OneDrive\cmd\Export-AntigravityReasoningTranscript.ps1` using `$env:ANTIGRAVITY_CONVERSATION_ID`.
   - In Copilot: invokes `D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1` using `$env:COPILOT_AGENT_SESSION_ID`.
   - If neither or both are detected, fails cleanly without speculative probing.
   The active provider normalizes the session events to a temporary JSONL file, invokes
   `LCM_Inventory\tools\Invoke-ReasoningAnalysis.ps1` with that temporary file, and cleans up the temporary
   file in `finally`. Do not require the operator to export a transcript manually during normal chat use.
5. Retain explicit `-TranscriptPath` (JSON or JSONL) as an offline fallback only; do not fabricate source evidence.
6. Make quoted text selection the primary interface, retaining numeric offsets only as an explicit legacy option.
7. List ambiguous matches and stop rather than silently selecting an event.
8. Produce reports only from selected transcript evidence.
9. Do not add any exception or special handling for `HaSSD06`.
10. Inactive Host Isolation: Never probe, access, scrape, or invoke the inactive IDE host. The active host alone supplies its
    transcript through its dedicated provider.
11. Provider Preservation: Strictly preserve `D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1` and
    `D:\OneDrive\cmd\Invoke-CopilotReasoningAnalysis.ps1` without modification or Antigravity bleed.
