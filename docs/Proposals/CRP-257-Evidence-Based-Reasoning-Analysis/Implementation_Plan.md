# CRP-257 Implementation Plan

1. Implement the active-host-only automatic transcript provider contract:
   - When `ar -From "<quoted chat input>" [-Until "<quoted chat input>"]` is entered in the active IDE host,
     the neutral dispatcher (`D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1`) detects the active host.
   - For Antigravity (`$env:ANTIGRAVITY_CONVERSATION_ID`), calls `D:\OneDrive\cmd\Export-AntigravityReasoningTranscript.ps1`
     (with protobuf parser `D:\OneDrive\cmd\Export-AntigravityExtractor.py`), extracting the active SQLite session
     from `~/.gemini/antigravity-ide/conversations/<SessionId>.db`.
   - For Copilot (`$env:COPILOT_AGENT_SESSION_ID`), calls `D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1`
     without touching or altering any existing Copilot files.
   - Normalizes session events to the canonical reasoning-analysis event contract (`id`, `timestamp`, `role`, `type`, `content`, `tool_name`, `arguments`).
   - Invokes `LCM_Inventory\tools\Invoke-ReasoningAnalysis.ps1` with the temporary JSONL document, and removes the file in a `finally` block.
   - Retain `-TranscriptPath` as an offline fallback; emit clear guidance if no active host is detected.
   - Enforce strict inactive host isolation: never probe, access, scrape, or invoke the inactive host.
2. Implement quote-based start and end selection, match listing, ambiguity errors, and legacy
   offset selection against supplied transcript events.
3. Generate a Markdown report containing only selected source events and no synthetic health assertions.
4. Correct the global OneDrive command wrappers (`ar.cmd`, `AnalyzeReasoning.cmd`, `ReasoningAnalysis.cmd`)
   and provide repository trampolines under `LCM_Inventory\Cmd\`.
5. Add Pester coverage for bounded quote selection, ambiguity failure, legacy offset mode,
   active host normalized transcript schema, temporary JSONL lifecycle/cleanup, inactive host isolation,
   dual-provider formats (Copilot and Antigravity), dispatcher provider selection, and Copilot provider preservation.
6. Run script syntax parsing and the expanded Pester test suite (10 tests).
