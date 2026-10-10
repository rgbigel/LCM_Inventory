# CRP-257 Walkthrough

## Operator Invocation

### Active IDE Host (Normal Chat Use)

In active chat with the AI host, the host automatically obtains and normalizes its current session transcript:

```powershell
ar -From 'please run the good morning routine now'
ar -From 'please run the good morning routine now' -Until 'found problems'
ar -Find 'good morning routine' -ListMatches
```

The active IDE host writes a temporary normalized JSONL file, invokes `LCM_Inventory\tools\Invoke-ReasoningAnalysis.ps1`,
and automatically deletes the temporary file in a `finally` block. No manual transcript export is required.

- **Antigravity Host**: When running inside an active Antigravity session (`$env:ANTIGRAVITY_CONVERSATION_ID`),
  `D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1` invokes `D:\OneDrive\cmd\Export-AntigravityReasoningTranscript.ps1`.
  The active conversation database at `~/.gemini/antigravity-ide/conversations/<SessionId>.db` is read via
  `D:\OneDrive\cmd\Export-AntigravityExtractor.py` and converted to normalized JSONL.
- **Copilot Host**: When running inside an active Copilot session (`$env:COPILOT_AGENT_SESSION_ID`),
  `D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1` invokes `D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1`.
  The Copilot provider remains strictly preserved and unmodified.
- **Inactive Host Isolation**: The dispatcher strictly verifies active host indicators and never probes
  or accesses the inactive host.

### Offline Fallback (Explicit File Export)

When running against an external or offline transcript file:

```powershell
ar -TranscriptPath .\conversation.jsonl -From 'please run the good morning routine now'
ar -TranscriptPath .\conversation.json -From 'good morning routine' -Until 'found problems'
```

If no source, quote match, or unambiguous selection exists, it fails explicitly and does not generate an analysis report.
The tool strictly uses provided transcript events and never invents evidence or probes inactive hosts.

## Verification

- PowerShell AST parsing passed for all scripts and test files.
- The proposal ledger parses as JSON.
- `ar`, `AnalyzeReasoning`, and `ReasoningAnalysis` all invoke the canonical dispatcher.
- Complete Pester coverage passed: 10 tests across provider formats, selection logic, cleanup, and Copilot preservation (0 failures).
