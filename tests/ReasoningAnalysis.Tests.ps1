Describe 'Invoke-ReasoningAnalysis transcript selection and host providers' {
  BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\tools\Invoke-ReasoningAnalysis.ps1'
    $dispatcherPath = 'D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1'
    $copilotProviderPath = 'D:\OneDrive\cmd\Export-CopilotReasoningTranscript.ps1'
    $antigravityProviderPath = 'D:\OneDrive\cmd\Export-AntigravityReasoningTranscript.ps1'
  }

  BeforeEach {
    $transcriptPath = Join-Path $TestDrive 'conversation.json'
    @'
{
  "events": [
    { "id": "one", "timestamp": "2026-10-10T13:54:57+02:00", "role": "user", "content": "please run the good morning routine now" },
    { "id": "two", "timestamp": "2026-10-10T13:55:00+02:00", "role": "assistant", "content": "I will identify the routine." },
    { "id": "three", "timestamp": "2026-10-10T13:55:01+02:00", "type": "tool_call", "tool_name": "powershell", "content": "Invoke-WorkspaceGoodMorning.ps1 -Force" },
    { "id": "four", "timestamp": "2026-10-10T14:01:00+02:00", "role": "user", "content": "found problems in two areas" }
  ]
}
'@ | Set-Content -LiteralPath $transcriptPath -Encoding UTF8
  }

  It 'creates a report bounded by quoted start and end text' {
    $reportPath = Join-Path $TestDrive 'report.md'
    & $scriptPath -TranscriptPath $transcriptPath -From 'good morning routine' -Until 'found problems' -OutputPath $reportPath

    $report = Get-Content -LiteralPath $reportPath -Raw
    $report | Should -Match 'event 1 / one'
    $report | Should -Match 'event 4 / four'
    $report | Should -Match 'Invoke-WorkspaceGoodMorning.ps1 -Force'
    $report | Should -Not -Match 'AST Integrity'
  }

  It 'fails clearly when quoted start text is ambiguous' {
    $reportPath = Join-Path $TestDrive 'ambiguous.md'
    Add-Content -LiteralPath $transcriptPath -Value ''
    $json = Get-Content -LiteralPath $transcriptPath -Raw | ConvertFrom-Json
    $json.events += [pscustomobject]@{ id = 'five'; timestamp = '2026-10-10T14:02:00+02:00'; role = 'user'; content = 'good morning routine again' }
    $json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $transcriptPath -Encoding UTF8

    { & $scriptPath -TranscriptPath $transcriptPath -From 'good morning routine' -OutputPath $reportPath } | Should -Throw '*Ambiguous start text*'
    Test-Path -LiteralPath $reportPath | Should -BeFalse
  }

  It 'supports legacy offset only with a supplied transcript' {
    $reportPath = Join-Path $TestDrive 'offset.md'
    & $scriptPath -TranscriptPath $transcriptPath -Offset 0 -OutputPath $reportPath

    (Get-Content -LiteralPath $reportPath -Raw) | Should -Match 'Legacy offset 0'
  }

  It 'stops before the current AR command flow when no explicit end is supplied' {
    $reportPath = Join-Path $TestDrive 'ar-boundary.md'
    $events = (Get-Content -LiteralPath $transcriptPath -Raw | ConvertFrom-Json).events
    $events += [pscustomobject]@{ id = 'five'; timestamp = '2026-10-10T14:02:00+02:00'; role = 'user'; content = 'AR' }
    $events += [pscustomobject]@{ id = 'six'; timestamp = '2026-10-10T14:02:01+02:00'; type = 'tool_call'; tool_name = 'powershell'; content = 'Invoke-ReasoningAnalysis.ps1' }
    @{ events = $events } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $transcriptPath -Encoding UTF8

    & $scriptPath -TranscriptPath $transcriptPath -From 'good morning routine' -OutputPath $reportPath

    $report = Get-Content -LiteralPath $reportPath -Raw
    $report | Should -Match 'event 4 / four'
    $report | Should -Not -Match 'event 5 / five'
    $report | Should -Not -Match 'Invoke-ReasoningAnalysis.ps1'
  }

  It 'parses active host normalized JSONL transcript with tool calls and step indices' {
    $jsonlPath = Join-Path $TestDrive 'active_host_session.jsonl'
    @'
{"step_index":1,"source":"USER_EXPLICIT","type":"USER_INPUT","content":"please inspect the storage layout"}
{"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","tool_calls":[{"toolAction":"Analyzing directory","name":"list_dir","CommandLine":"ls"}]}
{"step_index":3,"source":"SYSTEM","type":"PLANNER_RESPONSE","content":"Disk analysis completed"}
'@ | Set-Content -LiteralPath $jsonlPath -Encoding UTF8

    $reportPath = Join-Path $TestDrive 'active_host_report.md'
    & $scriptPath -TranscriptPath $jsonlPath -From 'inspect the storage layout' -OutputPath $reportPath

    $report = Get-Content -LiteralPath $reportPath -Raw
    $report | Should -Match 'event 1 / 1'
    $report | Should -Match 'ToolCall'
    $report | Should -Match 'Analyzing directory'
    $report | Should -Match 'Disk analysis completed'
  }

  It 'verifies active host temporary transcript lifecycle and cleanup contract' {
    $tempTranscript = Join-Path $TestDrive 'temp_session_transcript.jsonl'
    @'
{"id":"s1","role":"user","content":"run diagnostics now"}
{"id":"s2","role":"assistant","content":"executing test suite"}
'@ | Set-Content -LiteralPath $tempTranscript -Encoding UTF8

    $reportPath = Join-Path $TestDrive 'lifecycle_report.md'
    & $scriptPath -TranscriptPath $tempTranscript -From 'run diagnostics now' -OutputPath $reportPath

    Test-Path -LiteralPath $reportPath | Should -BeTrue
    Remove-Item -LiteralPath $tempTranscript -Force
    Test-Path -LiteralPath $tempTranscript | Should -BeFalse
  }

  It 'enforces offline fallback requirement when TranscriptPath is omitted' {
    { & $scriptPath -From 'test prompt' } | Should -Throw '*TranscriptPath is required for offline invocation*'
  }

  It 'normalizes the active Copilot session event log without reading another session' {
    $eventLogPath = Join-Path $TestDrive 'copilot-events.jsonl'
    $normalizedPath = Join-Path $TestDrive 'copilot-normalized.jsonl'
    @'
{"type":"user.message","id":"user-1","timestamp":"2026-10-10T14:00:00Z","data":{"content":"inspect this turn"}}
{"type":"tool.execution_start","id":"tool-1","timestamp":"2026-10-10T14:00:01Z","data":{"toolName":"powershell","arguments":{"command":"Get-Date"}}}
{"type":"assistant.message","id":"assistant-1","timestamp":"2026-10-10T14:00:02Z","data":{"content":"I inspected it."}}
'@ | Set-Content -LiteralPath $eventLogPath -Encoding UTF8

    & $copilotProviderPath -EventLogPath $eventLogPath -OutputPath $normalizedPath

    $events = @(Get-Content -LiteralPath $normalizedPath | ForEach-Object { $_ | ConvertFrom-Json })
    $events.Count | Should -Be 3
    $events[0].role | Should -Be 'user'
    $events[1].tool_name | Should -Be 'powershell'
    $events[2].content | Should -Be 'I inspected it.'
  }

  It 'normalizes the active Antigravity session transcript into the standard event contract' {
    $agLogPath = Join-Path $TestDrive 'antigravity-fixture.jsonl'
    $normalizedPath = Join-Path $TestDrive 'ag-normalized.jsonl'
    @'
{"id":"step-0","timestamp":"2026-10-10T13:50:12Z","role":"user","type":"message","content":"please run the good morning routine now"}
{"id":"step-4","timestamp":"2026-10-10T13:50:15Z","role":"tool","type":"tool_call","tool_name":"view_file","content":"Tool execution started: view_file","arguments":{"AbsolutePath":"D:\\Git_Repositories\\.mcp.json"}}
{"id":"step-63","timestamp":"2026-10-10T13:52:00Z","role":"assistant","type":"message","content":"# LCM GoodMorning Routine Report"}
'@ | Set-Content -LiteralPath $agLogPath -Encoding UTF8

    & $antigravityProviderPath -DatabasePath $agLogPath -OutputPath $normalizedPath

    $events = @(Get-Content -LiteralPath $normalizedPath | ForEach-Object { $_ | ConvertFrom-Json })
    $events.Count | Should -Be 3
    $events[0].role | Should -Be 'user'
    $events[0].content | Should -Match 'good morning routine'
    $events[1].type | Should -Be 'tool_call'
    $events[1].tool_name | Should -Be 'view_file'
    $events[2].role | Should -Be 'assistant'
    $events[2].content | Should -Match 'GoodMorning Routine Report'
  }

  It 'fails explicitly when no active supported host is detected' {
    $prevCopilot = $env:COPILOT_AGENT_SESSION_ID
    $prevAg = $env:ANTIGRAVITY_CONVERSATION_ID
    $prevAgAgent = $env:ANTIGRAVITY_AGENT
    try {
      $env:COPILOT_AGENT_SESSION_ID = ''
      $env:ANTIGRAVITY_CONVERSATION_ID = ''
      $env:ANTIGRAVITY_AGENT = ''
      { & $dispatcherPath -Auto -From 'some text' } | Should -Throw '*No active supported IDE host detected*'
    } finally {
      $env:COPILOT_AGENT_SESSION_ID = $prevCopilot
      $env:ANTIGRAVITY_CONVERSATION_ID = $prevAg
      $env:ANTIGRAVITY_AGENT = $prevAgAgent
    }
  }

  It 'preserves the Copilot provider files without alteration' {
    Test-Path -LiteralPath $copilotProviderPath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath 'D:\OneDrive\cmd\Invoke-CopilotReasoningAnalysis.ps1' -PathType Leaf | Should -BeTrue

    $copilotContent = Get-Content -LiteralPath $copilotProviderPath -Raw
    $copilotContent | Should -Match 'COPILOT_AGENT_SESSION_ID'
    $copilotContent | Should -Not -Match 'ANTIGRAVITY'
  }
}
