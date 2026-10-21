Describe 'Session failure mode analysis' {
  BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    $tool = Join-Path $root 'tools\Invoke-FailureModeAnalysis.ps1'
    Import-Module -Name (Join-Path $root 'modules\FailureModeAnalysis.psm1') -Force
    Import-Module -Name (Join-Path $root 'modules\ProposalManager.psm1') -Force
    $diagnostic = Join-Path $root 'tools\Show-LcmFailureDiagnostic.ps1'
    $events = @(
      [pscustomobject]@{Index=1; Id='a'; Role='user'; Type='message'; Text='inspect CRP-300'; Timestamp='one'; Failed=$false; Source='fixture:1'}
      [pscustomobject]@{Index=2; Id='b'; Role='tool'; Type='tool_result'; Text="Exception: The variable '`$old' cannot be retrieved because it has not been set."; Timestamp='two'; Failed=$true; Source='fixture:2'}
      [pscustomobject]@{Index=3; Id='c'; Role='user'; Type='message'; Text='inspect CRP-300 again'; Timestamp='three'; Failed=$false; Source='fixture:3'}
      [pscustomobject]@{Index=4; Id='d'; Role='tool'; Type='tool_result'; Text='[ERROR] access is denied'; Timestamp='four'; Failed=$true; Source='fixture:4'}
    )
  }

  It 'selects the latest literal user anchor and discloses repetition' {
    $s = Select-FailureEvidence -Events $events -From 'inspect CRP-300'
    $s.Matches | Should -Be 2
    $s.Events[0].Id | Should -Be 'c'
    $s.Number | Should -Be 300
  }

  It 'selects number-only anchors without matching arbitrary numbers or versions' {
    $s = Select-FailureEvidence -Events $events -Number 300
    $s.Events[0].Index | Should -Be 3
    $plain = @([pscustomobject]@{Index=1;Id='x';Role='user';Text='version 10.0.0, date 2026-10-21; 300 files'})
    { Select-FailureEvidence -Events $plain -Number 300 } | Should -Throw '*anchor was not found*'
    (Select-FailureEvidence -Events $plain).Number | Should -Be 0
    $bare = @([pscustomobject]@{Index=1;Id='bare';Role='user';Text='300'})
    (Select-FailureEvidence -Events $bare -Number 300).Number | Should -Be 300
  }

  It 'excludes an explicit current analysis command from the captured boundary' {
    $withCommand = $events + [pscustomobject]@{Index=5;Id='command';Role='user';Text='AnalyzeFailures -Number 300'}
    $s = Select-FailureEvidence -Events $withCommand -Number 300
    $s.Events[-1].Index | Should -Be 4
    $discussion = $events + [pscustomobject]@{Index=5;Id='request';Role='user';Text='please improve Invoke-FailureModeAnalysis.ps1 for CRP-300'}
    (Select-FailureEvidence -Events $discussion -Number 300).Events[0].Id | Should -Be 'request'
  }

  It 'recognizes all seven catalog symptoms and retains unclassified errors' {
    $messages = @(
      "The term '.Name' is not recognized as a name of a cmdlet.",
      "The term '=' is not recognized as a name of a cmdlet.",
      "The variable '`$x' cannot be retrieved because it has not been set.",
      'The process cannot access the file because another process has locked a portion.',
      'Access is denied.',
      'LCMLCMLCMClearBCReviewTemp.cmd',
      'stacked review diff and stale buffer overwrite',
      'some new unknown tool failure'
    )
    $inputEvents = @(foreach ($m in $messages) {
      [pscustomobject]@{Role='tool';Type='tool_result';Failed=$true;Text=$m;Source='fixture';Timestamp='time'}
    })
    $findings = @(Find-FailureEvidence -Events $inputEvents)
    @($findings.Category | Sort-Object -Unique).Count | Should -Be 8
  }

  It 'does not classify user discussion, tool commands, or successfully read catalog text as failures' {
    $inputs = @(
      [pscustomobject]@{Role='user';Type='message';Failed=$true;Text='[ERROR] access denied'}
      [pscustomobject]@{Role='tool';Type='tool_call';Failed=$true;Text='[ERROR] access denied'}
      [pscustomobject]@{Role='tool';Type='tool_result';Failed=$false;KnownSuccess=$true;Text='Exception: access denied'}
    )
    @(Find-FailureEvidence -Events $inputs).Count | Should -Be 0
  }

  It 'retains a failed shell exit even when the host tool transport succeeded' {
    $inputEvent = [pscustomobject]@{
      Role='tool';Type='tool.execution_complete';Tool='powershell';Failed=$false;KnownSuccess=$true
      Text="Exception: access denied`n<shellId: 1 completed with exit code 1>"
      Source='fixture';Timestamp='time'
    }
    @(Find-FailureEvidence -Events @($inputEvent)).Count | Should -BeGreaterThan 0
    $inputEvent.Text += "`n<shellId: 2 completed with exit code 0>"
    @(Find-FailureEvidence -Events @($inputEvent)).Count | Should -Be 0
  }

  It 'parses native Copilot result bodies without discarding failures' {
    $path = Join-Path $TestDrive 'copilot.jsonl'
    @(
      '{"type":"user.message","id":"u","timestamp":"now","data":{"content":"do 300"}}'
      '{"type":"tool.execution_complete","id":"t","timestamp":"now","data":{"success":false,"result":{"content":"access is denied"}}}'
    ) | Set-Content $path
    $parsed = @(Read-FailureTranscript $path)
    $parsed[0].Role | Should -Be 'user'
    $parsed[1].Text | Should -Be 'access is denied'
    @(Find-FailureEvidence $parsed).Count | Should -Be 1
  }

  It 'retains normalized provider failures even when their tool body is omitted' {
    $path = Join-Path $TestDrive 'normalized.jsonl'
    '{"id":"t","role":"tool","type":"tool_result","content":"Tool execution completed. Success: False"}' | Set-Content $path
    $parsed = @(Read-FailureTranscript $path)
    $parsed[0].Failed | Should -BeTrue
    @(Find-FailureEvidence $parsed)[0].Category | Should -Be 'Unclassified tool failure'
  }

  It 'reports a valid lifecycle action without calling the diagnostic or changing state' {
    $store = [pscustomobject]@{proposals=@([pscustomobject]@{id=300;crp_id='CRP-300';state='suggested'})}
    $text = Get-FailureLifecycleSection -Number 300 -Store $store -Action do -DiagnosticPath 'must-not-run.ps1'
    $text | Should -Match 'valid; no lifecycle failure'
    $store.proposals[0].state | Should -Be 'suggested'
  }

  It 'reports missing and ambiguous lifecycle context without throwing' {
    $store = [pscustomobject]@{
      proposals=@([pscustomobject]@{id=300;crp_id='CRP-300';state='suggested'})
      review_cohorts=@([pscustomobject]@{id='COH-300';proposal_ids=@(300,301)})
    }
    (Get-FailureLifecycleSection -Number 300 -Store $store -Action do -DiagnosticPath 'must-not-run.ps1') | Should -Match 'Ambiguous'
    (Get-FailureLifecycleSection -Number 0 -Store $store -Action do -DiagnosticPath 'must-not-run.ps1') | Should -Match 'Unavailable'
    (Get-FailureLifecycleSection -Number 999999 -Store $store -Action do -DiagnosticPath 'must-not-run.ps1') | Should -Match 'Unavailable'
  }

  It 'writes metadata, Summary, timezone and all category coverage to UTF-8 CRLF Markdown' {
    $selection = Select-FailureEvidence -Events $events -From 'again'
    $text = New-FailureMarkdown -Selection $selection -Findings @() -HostName Offline -SessionId fixture -Source fixture -Lifecycle @('valid') -Actions @('none') -Limitations @('limited') -GeneratedAt ([DateTimeOffset]'2026-10-21T19:20:30+02:00')
    $text | Should -Match 'Generator: Invoke-FailureModeAnalysis.ps1'
    $text | Should -Match 'Version: 10.0.0'
    $text | Should -Match '## Summary'
    $text | Should -Match '2026-10-21 19:20:30 \+02:00'
    $text | Should -Match 'Anchor: Literal user input: again'
    $text | Should -Not -Match '(?<!\r)\n'
  }

  It 'does not create a report when a requested anchor is absent' {
    $path = Join-Path $TestDrive 'absent.jsonl'
    '{"role":"user","content":"unrelated request"}' | Set-Content $path
    $outDir = Join-Path $TestDrive 'missing-anchor-output'
    New-Item $outDir -ItemType Directory | Out-Null
    { & $tool -TranscriptPath $path -From 'not present' -OutputDirectory $outDir } | Should -Throw '*anchor was not found*'
    @(Get-ChildItem $outDir).Count | Should -Be 0
  }

  It 'runs offline without lifecycle changes and never overwrites a same-second report' {
    $path = Join-Path $TestDrive 'offline.jsonl'
    @(
      '{"role":"user","content":"inspect this failure"}'
      '{"role":"tool","type":"tool_result","success":false,"content":"access is denied"}'
    ) | Set-Content $path
    $outDir = Join-Path $TestDrive 'reports'
    New-Item $outDir -ItemType Directory | Out-Null
    $before = (Get-FileHash (Join-Path $root 'data\proposals\proposals.json')).Hash
    $one = & $tool -TranscriptPath $path -From 'inspect this failure' -OutputDirectory $outDir
    $hash = (Get-FileHash $one.ReportPath).Hash
    $two = & $tool -TranscriptPath $path -From 'inspect this failure' -OutputDirectory $outDir
    $one.ReportPath | Should -Not -Be $two.ReportPath
    (Get-FileHash $one.ReportPath).Hash | Should -Be $hash
    (Get-FileHash (Join-Path $root 'data\proposals\proposals.json')).Hash | Should -Be $before
    $bytes = [IO.File]::ReadAllBytes($one.ReportPath)
    ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    (Get-Content $one.ReportPath -Raw) | Should -Match 'Show-Actions.ps1'
  }

  It 'preserves an existing timestamped report for a forced same-second collision' {
    $time = [DateTimeOffset]'2026-10-21T20:00:00+02:00'
    $one = Write-FailureMarkdown -Directory $TestDrive -GeneratedAt $time -Markdown 'original'
    $two = Write-FailureMarkdown -Directory $TestDrive -GeneratedAt $time -Markdown 'second'
    $one | Should -Not -Be $two
    (Get-Content $one -Raw) | Should -Be 'original'
    $two | Should -Match 'Catalog-of-Errors-and-Failure-Modes-20261021-200000-[a-f0-9]+\.md$'
  }

  It 'uses only the selected Copilot session and preserves native error bodies' {
    $names = @('COPILOT_AGENT_SESSION_ID','COPILOT_HOME','ANTIGRAVITY_CONVERSATION_ID','ANTIGRAVITY_AGENT')
    $saved = @{}
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    try {
      $env:COPILOT_HOME = Join-Path $TestDrive 'copilot-home'
      $env:COPILOT_AGENT_SESSION_ID = 'fixture'
      $env:ANTIGRAVITY_CONVERSATION_ID = ''
      $env:ANTIGRAVITY_AGENT = ''
      $session = Join-Path $env:COPILOT_HOME 'session-state\fixture'
      New-Item $session -ItemType Directory -Force | Out-Null
      @(
        '{"id":"u","timestamp":"now","type":"user.message","data":{"content":"check provider evidence"}}'
        '{"id":"t","timestamp":"now","type":"tool.execution_complete","data":{"success":false,"toolCallId":"call","result":{"content":"Access is denied."}}}'
      ) | Set-Content (Join-Path $session 'events.jsonl')
      $beforeTemps = @(Get-ChildItem ([IO.Path]::GetTempPath()) -Filter 'FailureModeAnalysis-*.jsonl' | Select-Object -ExpandProperty FullName)
      $result = & $tool -From 'check provider evidence' -OutputDirectory $TestDrive
      $report = Get-Content $result.ReportPath -Raw
      $report | Should -Match 'Host: Copilot'
      $report | Should -Match 'Permission or elevation boundary'
      $afterTemps = @(Get-ChildItem ([IO.Path]::GetTempPath()) -Filter 'FailureModeAnalysis-*.jsonl' | Select-Object -ExpandProperty FullName)
      ($afterTemps -join ';') | Should -Be ($beforeTemps -join ';')
    } finally {
      foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
  }

  It 'uses the Antigravity exporter plus only its selected session task logs' {
    $names = @('COPILOT_AGENT_SESSION_ID','ANTIGRAVITY_HOME','ANTIGRAVITY_CONVERSATION_ID','ANTIGRAVITY_AGENT')
    $saved = @{}
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    try {
      $env:COPILOT_AGENT_SESSION_ID = ''
      $env:ANTIGRAVITY_HOME = Join-Path $TestDrive 'antigravity-home'
      $env:ANTIGRAVITY_CONVERSATION_ID = 'fixture'
      $env:ANTIGRAVITY_AGENT = '1'
      $conversations = Join-Path $env:ANTIGRAVITY_HOME 'conversations'
      $tasks = Join-Path $env:ANTIGRAVITY_HOME 'brain\fixture\.system_generated\tasks'
      New-Item $conversations,$tasks -ItemType Directory -Force | Out-Null
      $db = Join-Path $conversations 'fixture.db'
      & 'D:\Tools\Python314\python.exe' -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute('CREATE TABLE steps (idx INTEGER, step_type INTEGER, status INTEGER, step_payload BLOB)'); c.execute('INSERT INTO steps VALUES (1,14,0,?)',(b'check antigravity provider evidence',)); c.commit(); c.close()" $db
      if ($LASTEXITCODE -ne 0) { throw 'Could not create the Antigravity provider fixture.' }
      '[ERROR] Access is denied.' | Set-Content (Join-Path $tasks 'task-1.log')
      $result = & $tool -From 'antigravity provider evidence' -OutputDirectory $TestDrive
      $report = Get-Content $result.ReportPath -Raw
      $report | Should -Match 'Host: Antigravity'
      $report | Should -Match 'Permission or elevation boundary'
      $report | Should -Match 'task-1.log'
      $report | Should -Match 'export times'
    } finally {
      foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
  }

  It 'reports a real invalid action without modifying the proposal ledger' {
    $path = Join-Path $root 'data\proposals\proposals.json'
    $before = (Get-FileHash $path).Hash
    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object state -EQ 'completed' | Select-Object -First 1)[0]
    $text = @(Get-FailureLifecycleSection -Number $proposal.id -Store $store -Action do -DiagnosticPath $diagnostic)
    ($text -join ' ') | Should -Match 'LIFECYCLE STATUS FAILURE REPORT'
    (Get-FileHash $path).Hash | Should -Be $before
  }
}
