<#
.SYNOPSIS
  Verifies session failure analysis and evidence preservation.
.NOTES
  Module: FailureModeAnalysis.Tests
  Purpose: Covers evidence selection, classification, serialization and analyzer integration.
  Path: LCM_Inventory/tests/FailureModeAnalysis.Tests.ps1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-10-21
#>
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
    $text | Should -Match 'Version: 10.0.1'
    $text | Should -Match '## Summary'
    $text | Should -Match '2026-10-21 19:20:30 \+02:00'
    $text | Should -Match 'Anchor: Literal user input: again'
    $text | Should -Not -Match '(?<!\r)\n'
  }

  It 'serializes complete event text, arguments, source identity and execution flow without rewriting strings' {
    $toolArguments = [pscustomobject]@{
      command = "git diff --cached`n@@ -1 +1 @@`n+literal \n characters"
      nested = [pscustomobject]@{ patch = "diff --git a/a b/a`n+actual patch" }
    }
    $inputEvents = @(
      [pscustomobject]@{Index=1;Id='u1';Role='user';Type='message';Text="inspect CRP-304`nsecond line";Timestamp='2026-10-21T20:00:00+02:00';Failed=$false;Source='events.jsonl:1 (event 1)';Arguments=$null;KnownSuccess=$false}
      [pscustomobject]@{Index=2;Id='t1';Role='tool';Type='tool.execution_start';Text='';Timestamp='';Failed=$false;Source='events.jsonl:2 (event 2)';Arguments=$toolArguments;KnownSuccess=$false;Tool='powershell';CallId='call-1';TurnId='turn-1';ParentId='a1';ToolTitle='Inspect diff'}
    )
    $selection = Select-FailureEvidence -Events $inputEvents -Number 304
    $structured = New-FailureStructuredEvidence -Selection $selection -Findings @() -HostName Offline -SessionId fixture -Source 'events.jsonl' -Lifecycle @('read-only') -Actions @() -Limitations @() -GeneratedAt ([DateTimeOffset]'2026-10-21T20:00:00+02:00')
    $roundTrip = $structured | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $roundTrip.Events[1].Arguments.command | Should -Be $toolArguments.command
    $roundTrip.Events[1].Arguments.nested.patch | Should -Be $toolArguments.nested.patch
    $roundTrip.Events[1].Source | Should -Be 'events.jsonl:2 (event 2)'
    $roundTrip.ExecutionFlow[0].Arguments.command | Should -Be $toolArguments.command
    $roundTrip.Events[0].Text | Should -Be "inspect CRP-304`nsecond line"
    $roundTrip.Producer | Should -Be 'Invoke-FailureModeAnalysis.ps1'
    $roundTrip.ProducerVersion | Should -Be '10.0.1'
  }

  It 'writes a Markdown and JSON sibling pair without a BOM or evidence loss' {
    $selection = Select-FailureEvidence -Events $events -From 'again'
    $arguments = [pscustomobject]@{diff = "diff --git a/file b/file`n+full patch"}
    $selection.Events += [pscustomobject]@{
      Index=5;Id='tool';Role='tool';Type='tool.execution_start';Text='';Timestamp='';Failed=$false
      KnownSuccess=$false;Tool='shell';CallId='call-5';TurnId='';ParentId='';Source='fixture:5';Arguments=$arguments;ToolTitle=''
    }
    $evidence = New-FailureStructuredEvidence -Selection $selection -Findings @() -HostName Offline -SessionId fixture -Source fixture -Lifecycle @() -Actions @() -Limitations @() -GeneratedAt ([DateTimeOffset]'2026-10-21T20:00:00+02:00')
    $reports = Write-FailureReportPair -Directory $TestDrive -GeneratedAt ([DateTimeOffset]'2026-10-21T20:00:00+02:00') -Markdown 'report' -Evidence $evidence
    [IO.Path]::GetFileNameWithoutExtension($reports.MarkdownPath) | Should -Be ([IO.Path]::GetFileNameWithoutExtension($reports.JsonPath))
    $bytes = [IO.File]::ReadAllBytes($reports.JsonPath)
    ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    $written = Get-Content -LiteralPath $reports.JsonPath -Raw | ConvertFrom-Json
    $written.Events[-1].Arguments.diff | Should -Be "diff --git a/file b/file`n+full patch"
  }

  It 'does not create a report when a requested anchor is absent' {
    $path = Join-Path $TestDrive 'absent.jsonl'
    '{"role":"user","content":"unrelated request"}' | Set-Content $path
    $outDir = Join-Path $TestDrive 'missing-anchor-output'
    New-Item $outDir -ItemType Directory | Out-Null
    { & $tool -TranscriptPath $path -From 'not present' -OutputDirectory $outDir -NoLaunch -SnapshotRoot (Join-Path $outDir 'snapshots') } | Should -Throw '*anchor was not found*'
    @(Get-ChildItem $outDir).Count | Should -Be 0
  }

  It 'rejects a custom snapshot root before analysis or report writes when launch is requested' {
    $path = Join-Path $TestDrive 'custom-root.jsonl'
    '{"role":"user","content":"inspect custom snapshot behavior"}' | Set-Content -LiteralPath $path
    $outDir = Join-Path $TestDrive 'custom-root-output'
    New-Item -Path $outDir -ItemType Directory | Out-Null
    $customRoot = Join-Path $TestDrive 'custom-root-snapshots'
    { & $tool -TranscriptPath $path -From 'inspect custom snapshot behavior' -OutputDirectory $outDir -SnapshotRoot $customRoot } | Should -Throw '*requires -NoLaunch*'
    @(Get-ChildItem -LiteralPath $outDir).Count | Should -Be 0
    Test-Path -LiteralPath $customRoot | Should -BeFalse
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
    $one = & $tool -TranscriptPath $path -From 'inspect this failure' -OutputDirectory $outDir -NoLaunch -SnapshotRoot (Join-Path $outDir 'snapshots')
    $hash = (Get-FileHash $one.ReportPath).Hash
    $two = & $tool -TranscriptPath $path -From 'inspect this failure' -OutputDirectory $outDir -NoLaunch -SnapshotRoot (Join-Path $outDir 'snapshots')
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
      $result = & $tool -From 'check provider evidence' -OutputDirectory $TestDrive -NoLaunch -SnapshotRoot (Join-Path $TestDrive 'copilot-snapshots')
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
      $result = & $tool -From 'antigravity provider evidence' -OutputDirectory $TestDrive -NoLaunch -SnapshotRoot (Join-Path $TestDrive 'antigravity-snapshots')
      $report = Get-Content $result.ReportPath -Raw
      $report | Should -Match 'Host: Antigravity'
      $report | Should -Match 'Permission or elevation boundary'
      $report | Should -Match 'task-1.log'
      $report | Should -Match 'export timestamps are omitted'
      $result.Findings | Should -Be 0
      $result.Unresolved | Should -Be 1
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

  It 'excludes the supplied dependency-index diff rather than inventing Dispatch errors' {
    $text = @'
commit 73ae48c
diff --git a/data/dependencies/forward-index.json b/data/dependencies/forward-index.json
@@ -48270,8 +48270,8 @@
-      "caller_file": "D:\\Git_Repositories\\LCM_Inventory\\tools\\Invoke-LcmProtocol.ps1",
-      "caller_line": 142,
-      "supplied_arguments": "Write-ToolLog -Message \"Dispatch error: $_\" -Level ERROR",
+      "caller_file": "D:\\Git_Repositories\\LCM_Inventory\\tools\\Invoke-MacriumBcrReview.ps1",
+      "caller_line": 87,
+      "supplied_arguments": "Test-Path -LiteralPath (Join-Path $lcmAiPath '.git')",
'@
    $event = [pscustomobject]@{Role='tool';Type='task_log';Failed=$false;Text=$text;Source='task-602.log';Timestamp=''}
    @(Find-FailureEvidence @($event)).Count | Should -Be 0
  }

  It 'reports raw diagnostics as unresolved and gives an exact line and numbered context' {
    $event = [pscustomobject]@{
      Role='tool';Type='task_log';Failed=$false;Source='task-7.log';Timestamp=''
      Text="starting`n[ERROR] Access is denied.`nat Invoke-Test, D:\repo\test.ps1: line 42`nfinished"
    }
    $finding = @(Find-FailureEvidence @($event))[0]
    $finding.Disposition | Should -Be 'Unresolved evidence'
    $finding.Source | Should -Be 'task-7.log:2'
    ($finding.Context -join "`n") | Should -Match '2: \[ERROR\] Access is denied'
    ($finding.Locations -join "`n") | Should -Match 'test.ps1: line 42'
    $finding.Timestamp | Should -BeNullOrEmpty
  }

  It 'confirms nonzero task exits without promoting quoted or source strings' {
    $event = [pscustomobject]@{
      Role='tool';Type='task_log';Failed=$false;Source='task-8.log';Timestamp=''
      Text="[ERROR] Access is denied.`nProcess exited with code 1"
    }
    $finding = @(Find-FailureEvidence @($event))[0]
    $finding.Disposition | Should -Be 'Confirmed runtime failure'
    $finding.ExitStatus | Should -Be '1'
    $event.Text = "[ERROR] Access is denied.`nProcess exited with code 0"
    @(Find-FailureEvidence @($event)).Count | Should -Be 0
    $event.Text = '```text' + "`nProcess exited with code 1`n" + '```'
    @(Find-FailureEvidence @($event)).Count | Should -Be 0
    $event.Text = "diff --git a/log b/log`nProcess exited with code 1"
    @(Find-FailureEvidence @($event)).Count | Should -Be 0
    $event.Text = 'Write-ToolLog -Message "Dispatch error: $_" -Level ERROR'
    @(Find-FailureEvidence @($event)).Count | Should -Be 0
  }

  It 'deduplicates repeated evidence from one execution but preserves independent calls' {
    $one = [pscustomobject]@{Role='tool';Type='tool.execution_complete';CallId='one';Failed=$true;Source='e1';Timestamp='';Text="[ERROR] Access is denied.`n[ERROR] Access is denied."}
    $two = [pscustomobject]@{Role='tool';Type='tool.execution_complete';CallId='two';Failed=$true;Source='e2';Timestamp='';Text=$one.Text}
    @(Find-FailureEvidence @($one,$one,$two)).Count | Should -Be 2
  }

  It 'uses exact operational-log text only as unverified corroboration' {
    $path = Join-Path $TestDrive 'operation.log'
    @('unrelated', '[ERROR] The actual runtime diagnostic is sufficiently specific.') | Set-Content $path
    $event = [pscustomobject]@{Role='tool';Type='tool_result';Failed=$true;Source='result';Timestamp='';Text='[ERROR] The actual runtime diagnostic is sufficiently specific.'}
    $finding = @(Find-FailureEvidence @($event) -OperationalLogPaths @($path))[0]
    $finding.Related.Count | Should -Be 1
    $finding.Related[0] | Should -Match 'operation.log:2:'
    $finding.Related[0] | Should -Match 'execution identity unverified'
  }

  It 'retains successful executions, physical JSONL lines, explicit IDs and stated tool purpose' {
    $path = Join-Path $TestDrive 'flow.jsonl'
    @(
      '{"id":"u","type":"user.message","data":{"content":"Inspect repository status","turnId":"turn-1"}}'
      ''
      '{"id":"a","type":"assistant.message","data":{"content":"I will inspect the working tree."}}'
      '{"id":"s","parentId":"a","type":"tool.execution_start","data":{"toolCallId":"call-1","turnId":"turn-1","toolName":"powershell","toolTitle":"Check status","arguments":{"command":"git status"}}}'
      '{"id":"c","timestamp":"2026-10-21T20:00:00+02:00","type":"tool.execution_complete","data":{"toolCallId":"call-1","success":true,"result":{"content":"clean\n<shellId: 1 completed with exit code 0>"}}}'
    ) | Set-Content $path
    $parsed = @(Read-FailureTranscript $path)
    $flow = @(Get-FailureExecutionFlow $parsed)
    $flow.Count | Should -Be 1
    $flow[0].Source | Should -Match 'flow.jsonl:4'
    $flow[0].Request | Should -Match 'Inspect repository status'
    $flow[0].Purpose | Should -Match 'Check status'
    $flow[0].AssistantContext | Should -Match 'not proof of purpose'
    $flow[0].Relationship | Should -Match 'Same recorded turn ID'
    $flow[0].Outcome | Should -Match 'Command exit code: 0'
    $flow[0].ParentId | Should -Be 'a'
    $flow[0].Arguments.command | Should -Be 'git status'
    @(Find-FailureEvidence $parsed).Count | Should -Be 0
    $parsed[2].Arguments | Add-Member -NotePropertyName description -NotePropertyValue 'Inspect working tree for the requested status check'
    @(Get-FailureExecutionFlow $parsed)[0].Purpose | Should -Match 'Inspect working tree.*tool argument description'
  }

  It 'does not invent normalized provider timestamps, purpose, or linkage by proximity' {
    $path = Join-Path $TestDrive 'unlinked.jsonl'
    @(
      '{"role":"user","content":"Check something"}'
      '{"role":"tool","type":"tool_call","tool_name":"powershell","timestamp":"2026-10-21T20:00:00+02:00","arguments":{"command":"git status"}}'
      '{"role":"tool","type":"tool_result","content":"Tool execution completed."}'
    ) | Set-Content $path
    $parsed = @(Read-FailureTranscript $path)
    $parsed[1].Timestamp | Should -BeNullOrEmpty
    $flow = @(Get-FailureExecutionFlow $parsed)
    $flow[0].Purpose | Should -Be 'No explicit purpose recorded.'
    $flow[0].Outcome | Should -Match 'Unknown'
    $flow[0].Relationship | Should -Match 'context only'
  }

  It 'renders confirmed and unresolved evidence separately without filesystem error times' {
    $inputEvents = @(
      [pscustomobject]@{Role='tool';Type='task_log';Failed=$true;Text='[ERROR] Denied runtime operation';Source='task-1.log';Timestamp=''}
      [pscustomobject]@{Role='tool';Type='task_log';Failed=$false;Text='[ERROR] Uncertain raw diagnostic';Source='task-2.log';Timestamp=''}
    )
    $selection = Select-FailureEvidence -Events $events -From 'again'
    $text = New-FailureMarkdown -Selection $selection -Findings @(Find-FailureEvidence $inputEvents) -HostName Offline -SessionId fixture -Source fixture -Lifecycle @() -Actions @() -Limitations @() -GeneratedAt ([DateTimeOffset]::Now)
    $text | Should -Match 'Confirmed runtime failure findings: 1'
    $text | Should -Match 'Unresolved evidence \(not counted as confirmed errors\): 1'
    $text | Should -Match 'Source: task-1.log:1'
    $text | Should -Not -Match '; time:|Recorded native event time'
    $text | Should -Match '## Execution flow and recorded purpose'
  }
}
