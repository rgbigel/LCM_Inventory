<#
.SYNOPSIS
  Evidence selection and Markdown rendering for session failure analysis.
.NOTES
  Module: FailureModeAnalysis
  Purpose: Selects, classifies and serializes retained session failure evidence.
  Path: LCM_Inventory/modules/FailureModeAnalysis.psm1
  Authors: Rolf, Copilot
  Version: 10.0.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FailureProperty {
  [CmdletBinding()]
  param([AllowNull()][object]$Value, [string]$Name, [AllowNull()][object]$Default = '')
  if ($null -ne $Value -and $Value.PSObject.Properties[$Name]) {
    return $Value.$Name
  }
  return $Default
}

function Get-FailureAnalysisProducer {
  [CmdletBinding()]
  param()
  [pscustomobject][ordered]@{
    Name = 'Invoke-FailureModeAnalysis.ps1'
    Version = '10.0.1'
  }
}

function Read-FailureTranscript {
  [CmdletBinding()]
  param([string]$Path)
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { throw "Transcript is empty: $Path" }
  if ([IO.Path]::GetExtension($Path) -ieq '.jsonl') {
    $sourceLines = [Collections.Generic.List[int]]::new()
    $lineNumber = 0
    $items = @(foreach ($line in ($raw -split '\r?\n')) {
      $lineNumber++
      if (-not [string]::IsNullOrWhiteSpace($line)) {
        $sourceLines.Add($lineNumber)
        $line | ConvertFrom-Json -ErrorAction Stop
      }
    })
  } else {
    $document = $raw | ConvertFrom-Json -ErrorAction Stop
    $items = if ($document -is [array]) { @($document) } else { @(Get-FailureProperty $document 'events' @()) }
  }
  if ($items.Count -eq 0) { throw "Transcript contains no events: $Path" }
  $index = 0
  $toolNames = @{}
  foreach ($item in $items) {
    $index++
    $type = [string](Get-FailureProperty $item 'type')
    $data = Get-FailureProperty $item 'data' $item
    $callId = [string](Get-FailureProperty $data 'toolCallId' (Get-FailureProperty $item 'tool_call_id'))
    if ($type -eq 'tool.execution_start' -and $callId) {
      $toolNames[$callId] = $data
    }
    $start = if ($callId -and $toolNames.ContainsKey($callId)) { $toolNames[$callId] } else { $data }
    $toolName = [string](Get-FailureProperty $start 'toolName' (Get-FailureProperty $item 'tool_name'))
    $role = [string](Get-FailureProperty $item 'role')
    if ($type -eq 'user.message') { $role = 'user' }
    if ($type -eq 'assistant.message') { $role = 'assistant' }
    if ($type -like 'tool.*') { $role = 'tool' }
    $content = [string](Get-FailureProperty $data 'content')
    if ($type -eq 'tool.execution_complete') {
      $result = Get-FailureProperty $data 'result' $null
      $content = [string](Get-FailureProperty $result 'content')
      $errorValue = Get-FailureProperty $data 'error' $null
      if ($null -ne $errorValue) { $content += "`n" + ($errorValue | ConvertTo-Json -Depth 20 -Compress) }
    }
    $failed = (Get-FailureProperty $data 'success' $null) -eq $false
    $failed = $failed -or $null -ne (Get-FailureProperty $data 'error' $null)
    $failed = $failed -or (Get-FailureProperty $data 'isError' $false) -eq $true
    $resultValue = Get-FailureProperty $data 'result' $null
    $failed = $failed -or (Get-FailureProperty $resultValue 'isError' $false) -eq $true
    if ($role -eq 'tool' -and $type -eq 'tool_result' -and $content -match '^Tool execution completed\. Success: False\s*$') { $failed = $true }
    $time = Get-FailureProperty $item 'timestamp'
    $timeText = if ($time -is [datetime] -or $time -is [DateTimeOffset]) { $time.ToString('o') } else { [string]$time }
    [pscustomobject]@{
      Index = $index
      Id = [string](Get-FailureProperty $item 'id' "event-$index")
      Timestamp = if ($type -like 'tool.*' -or $type -in @('user.message', 'assistant.message')) { $timeText } else { '' }
      Role = $role
      Type = $type
      Tool = $toolName
      Text = $content
      Failed = $failed
      KnownSuccess = (Get-FailureProperty $data 'success' $null) -eq $true
      CallId = $callId
      TurnId = [string](Get-FailureProperty $start 'turnId')
      ParentId = [string](Get-FailureProperty $item 'parentId')
      Arguments = Get-FailureProperty $start 'arguments' $null
      ToolTitle = [string](Get-FailureProperty $start 'toolTitle')
      Source = if ([IO.Path]::GetExtension($Path) -ieq '.jsonl') { "${Path}:$($sourceLines[$index - 1]) (event $index)" } else { "$Path (event $index)" }
    }
  }
}

function Get-FailureItemReferences {
  [CmdletBinding()]
  param([string]$Text)
  $pattern = '(?i)(?:\b(?:CRP|BUG|COH)[ -]+|(?<!\w)#)(?<id>\d+)\b|\b(?:do|complete|bcr|proceed|verify|hold|item|proposal)\s+(?<id>\d+)\b|^\s*(?<id>\d+)\s*$'
  foreach ($match in [regex]::Matches($Text, $pattern)) {
    $number = 0
    if ([int]::TryParse($match.Groups['id'].Value, [ref]$number)) { $number }
  }
}

function Select-FailureEvidence {
  [CmdletBinding()]
  param([object[]]$Events, [int]$Number, [string]$From)
  $cutoff = @($Events | Where-Object {
    $_.Role -eq 'user' -and $_.Text -match '^\s*(?:AnalyzeFailures\b|Invoke-FailureModeAnalysis\.ps1\b|(?:&\s+)?(?:\.\\|[A-Za-z]:\\)[^\r\n]*Invoke-FailureModeAnalysis\.ps1\b|pwsh(?:\.exe)?\s+.*-File\s+.*Invoke-FailureModeAnalysis\.ps1\b)'
  } | Select-Object -Last 1)
  if ($cutoff.Count) { $Events = @($Events | Where-Object Index -LT $cutoff[0].Index) }
  $candidates = @()
  if ($From) {
    $candidates = @($Events | Where-Object {
      $_.Role -eq 'user' -and $_.Text.IndexOf($From, [StringComparison]::OrdinalIgnoreCase) -ge 0
    })
  } elseif ($Number -gt 0) {
    $candidates = @($Events | Where-Object {
      $_.Role -in @('user', 'assistant') -and $Number -in @(Get-FailureItemReferences $_.Text)
    })
  }
  if (($From -or $Number -gt 0) -and $candidates.Count -eq 0) {
    throw "Requested conversation anchor was not found: $From $Number"
  }
  $selected = if ($candidates.Count) { @($Events | Where-Object Index -GE $candidates[-1].Index) } else { @($Events) }
  $resolvedNumber = $Number
  if ($resolvedNumber -eq 0) {
    foreach ($event in $selected) {
      if ($event.Role -in @('user', 'assistant')) {
        $references = @(Get-FailureItemReferences $event.Text)
        if ($references.Count) { $resolvedNumber = $references[-1] }
      }
    }
  }
  $anchor = if ($From) { "Literal user input: $From" } elseif ($Number) { "Item number: $Number" } else { 'Full captured session; last explicit item reference' }
  [pscustomobject]@{ Events = $selected; Number = $resolvedNumber; Matches = $candidates.Count; Anchor = $anchor }
}

function Get-FailurePatterns {
  [CmdletBinding()]
  param()
  @(
    @{ Name = 'Pipeline variable stripping'; Pattern = "(?i)(?:term\s+['`"]\.\w+['`"].*not recognized|\.\w+:\s*The term)"; Advice = 'Check outer-shell expansion of $_; use safe command transport.' }
    @{ Name = 'Bare assignment stripping'; Pattern = "(?i)(?:term\s+['`"]=['`"].*not recognized|^=\s*:.*not recognized)"; Advice = 'Check outer-shell expansion of assignment variables.' }
    @{ Name = 'StrictMode uninitialized variable'; Pattern = '(?i)VariableIsUndefined|variable .+ cannot be retrieved because it has not been set'; Advice = 'Initialize variables and inspect the failing branch; parse and test the script.' }
    @{ Name = 'File lock contention'; Pattern = '(?i)SharingViolation|cannot access the file because.*(?:used|locked)|locked a portion'; Advice = 'Identify the actual file-handle owner before changing shared files.' }
    @{ Name = 'Permission or elevation boundary'; Pattern = '(?i)access (?:is )?denied|UnauthorizedAccessException'; Advice = 'Verify required privileges and the authorized elevation route; do not assume elevation is the cause.' }
    @{ Name = 'Repeated tool prefix'; Pattern = '(?i)(?:LCM){3,}\w*'; Advice = 'Check idempotent prefix removal and non-capturing repetition.' }
    @{ Name = 'IDE diff or buffer overwrite'; Pattern = '(?i)stacked (?:review )?diff|stale (?:in-memory )?buffer|older (?:review )?diff.*overwrite|buffer clobber'; Advice = 'Compare current disk/buffer state and consolidate edits; symptom alone does not prove data loss.' }
  )
}

function Get-FailureTerminalExit {
  [CmdletBinding()]
  param([object]$Event, [string[]]$Lines)
  if ($null -eq $Lines) { $Lines = @(($Event.Text -replace '\x1b\[[0-9;]*m', '') -split '\r?\n') }
  $last = $Lines.Count - 1
  while ($last -ge 0 -and [string]::IsNullOrWhiteSpace($Lines[$last])) { $last-- }
  $inFence = $false
  $inDiff = $false
  for ($i = 0; $i -le $last; $i++) {
    if ($Lines[$i] -match '^diff --git |^@@ .* @@|^commit [a-f0-9]{7,40}$') { $inDiff = $true }
    if ($Lines[$i] -match '^\s*`{3,}') { $inFence = -not $inFence }
  }
  if ($last -ge 0 -and -not $inFence -and (-not $inDiff -or $Event.Type -eq 'tool.execution_complete') -and
    $Lines[$last] -match '^<shellId:.*completed with exit code (?<code>-?\d+)>\s*$|^Process exited with code (?<code>-?\d+)\s*$') {
    [pscustomobject]@{ Code = [int]$Matches.code; Line = $last + 1 }
  }
}

function Invoke-Investigator {
  [CmdletBinding()]
  param([object]$Event, [string[]]$OperationalLogPaths = @())
  $lines = @(($Event.Text -replace '\x1b\[[0-9;]*m', '') -split '\r?\n')
  $inDiff = $false
  $inFence = $false
  $candidates = [Collections.Generic.List[object]]::new()
  $excluded = 0
  $terminalExit = Get-FailureTerminalExit -Event $Event -Lines $lines
  $exitCode = if ($null -ne $terminalExit) { $terminalExit.Code } else { $null }
  $exitLine = if ($null -ne $terminalExit) { $terminalExit.Line } else { 0 }
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^diff --git |^@@ .* @@|^commit [a-f0-9]{7,40}$') { $inDiff = $true }
    if ($line -match '^\s*`{3,}') { $inFence = -not $inFence; continue }
    if ($i + 1 -eq $exitLine) { continue }
    $quoted = $inDiff -or $inFence -or $line -match '^\s*(?:[+-]\s*|"(?:supplied_arguments|content|command|Pattern|pattern)"\s*:|#|//)'
    $runtime = $line -match '^\s*(?:\d{4}-\d{2}-\d{2}[T ][\d:.Z+-]+\s+)?(?:\[ERROR\]|[A-Za-z.]*Exception\s*:|Error\s*:|FullyQualifiedErrorId\s*:|Status\s*:\s*FAILED\b)'
    $symptom = $line -match '(?i)not recognized|cannot be retrieved because it has not been set|access (?:is )?denied|cannot access the file|SharingViolation|LCMLCMLCM|stale buffer|stacked (?:review )?diff'
    if ($quoted) {
      if ($runtime -or $symptom -or $line -match '(?i)error:') { $excluded++ }
      continue
    }
    if ($runtime -or ($Event.Failed -and $symptom)) {
      $candidates.Add([pscustomobject]@{ Line = $i + 1; Text = $line.Trim(); Runtime = $runtime })
    }
  }
  $knownSuccess = Get-FailureProperty $Event 'KnownSuccess' $false
  $shell = (Get-FailureProperty $Event 'Tool') -match '(?i)(?:^|[._])(?:powershell|bash|shell|run_shell)$'
  $confirmed = $Event.Failed -or (($shell -or $Event.Type -eq 'task_log') -and $null -ne $exitCode -and $exitCode -ne 0)
  if ($null -ne $exitCode -and $exitCode -eq 0 -and -not $Event.Failed) { $candidates.Clear() }
  if ($knownSuccess -and -not $Event.Failed -and -not ($shell -and $null -ne $exitCode -and $exitCode -ne 0)) {
    $candidates.Clear()
  }
  if (-not $candidates.Count -and $confirmed) {
    $candidates.Add([pscustomobject]@{ Line = $exitLine; Text = 'Execution reported failure; no trustworthy runtime diagnostic was recovered.'; Runtime = $false })
  }
  $seen = @{}
  foreach ($candidate in $candidates) {
    if ($seen.ContainsKey($candidate.Text)) { continue }
    $seen[$candidate.Text] = $true
    $isConfirmed = $confirmed
    $context = @()
    if ($candidate.Line -gt 0) {
      $first = [Math]::Max(0, $candidate.Line - 3)
      $last = [Math]::Min($lines.Count - 1, $candidate.Line + 5)
      $context = @(for ($j = $first; $j -le $last; $j++) { '{0}: {1}' -f ($j + 1), $lines[$j] })
    }
    $source = $Event.Source
    if ($Event.Type -eq 'task_log' -and $candidate.Line -gt 0) { $source = "$($Event.Source):$($candidate.Line)" }
    elseif ($candidate.Line -gt 0) { $source += "; output line $($candidate.Line)" }
    $locations = @($context | Where-Object { $_ -match '(?i)\.ps(?:1|m1):\s*\d+|^\d+:\s*(?:at .+, .+: line \d+|ScriptStackTrace\s*:)' })
    $related = @()
    # Exact diagnostic text is corroboration, not proof of the same execution.
    if ($isConfirmed -and $candidate.Text.Length -ge 24) {
      foreach ($path in $OperationalLogPaths) {
        $matches = @(Select-String -LiteralPath $path -SimpleMatch $candidate.Text | Select-Object -First 3)
        foreach ($hit in $matches) { $related += "$($hit.Path):$($hit.LineNumber): $($hit.Line) [exact-text match; execution identity unverified]" }
      }
    }
    [pscustomobject]@{
      Disposition = if ($isConfirmed) { 'Confirmed runtime failure' } else { 'Unresolved evidence' }
      Evidence = $candidate.Text; Source = $source; Context = $context; Locations = $locations
      Timestamp = [string](Get-FailureProperty $Event 'Timestamp')
      Related = $related; Excluded = $excluded
      Command = Get-FailureProperty $Event 'Arguments' $null
      CallId = Get-FailureProperty $Event 'CallId'
      ExitStatus = if ($null -ne $exitCode) { [string]$exitCode } else { 'not recorded' }
    }
  }
}

function Get-FailureExecutionFlow {
  [CmdletBinding()]
  param([AllowEmptyCollection()][object[]]$Events)
  $request = $null
  $purpose = $null
  $calls = @{}
  foreach ($event in $Events) {
    if ($event.Role -eq 'user') { $request = $event; $purpose = $null; continue }
    if ($event.Role -eq 'assistant' -and $event.Text) { $purpose = $event; continue }
    if ($event.Role -ne 'tool') { continue }
    $callId = [string](Get-FailureProperty $event 'CallId')
    if ($event.Type -match 'execution_start|tool_call') {
      $arguments = Get-FailureProperty $event 'Arguments' $null
      $description = [string](Get-FailureProperty $arguments 'description')
      $entry = [pscustomobject]@{
        Source = $event.Source; Tool = Get-FailureProperty $event 'Tool'; CallId = $callId
        ParentId = Get-FailureProperty $event 'ParentId'; TurnId = Get-FailureProperty $event 'TurnId'
        Arguments = $arguments
        Request = if ($request) { "$($request.Text) [source: $($request.Source)]" } else { 'Unavailable in selected scope.' }
        Purpose = if ($description) { "$description [tool argument description; source: $($event.Source)]" } elseif (Get-FailureProperty $event 'ToolTitle') { "$(Get-FailureProperty $event 'ToolTitle') [tool title; source: $($event.Source)]" } else { 'No explicit purpose recorded.' }
        AssistantContext = if ($purpose) { "$($purpose.Text) [source: $($purpose.Source); preceding statement, not proof of purpose]" } else { 'No preceding assistant statement in selected scope.' }
        Relationship = 'Preceding conversation context only; request-to-execution causation and authorization are not established.'
        Outcome = 'Unknown: no explicitly linked completion record.'
      }
      if ($request -and $entry.TurnId -and $entry.TurnId -eq (Get-FailureProperty $request 'TurnId')) {
        $entry.Relationship = 'Same recorded turn ID as user request; not proof of authorization or appropriateness.'
      }
      if ($callId) { $calls[$callId] = $entry }
      $entry
    } elseif ($callId -and $calls.ContainsKey($callId) -and $event.Type -match 'complete|result') {
      $terminalExit = if ($calls[$callId].Tool -match '(?i)(?:^|[._])(?:powershell|bash|shell|run_shell)$') { Get-FailureTerminalExit -Event $event } else { $null }
      $calls[$callId].Outcome = if ($event.Failed) { "Failed; completion: $($event.Source)" } elseif (Get-FailureProperty $event 'KnownSuccess' $false) {
        if ($null -ne $terminalExit) {
          "Command exit code: $($terminalExit.Code); completion explicitly linked by call ID: $($event.Source)"
        } else { "Tool transport succeeded; runtime outcome not recorded. Completion explicitly linked by call ID: $($event.Source)" }
      } else { "Completion linked by call ID; runtime status unavailable. Source: $($event.Source)" }
    }
  }
}

function Find-FailureEvidence {
  [CmdletBinding()]
  param([AllowEmptyCollection()][object[]]$Events, [string[]]$OperationalLogPaths = @())
  $patterns = @(Get-FailurePatterns)
  $seenExecutions = @{}
  foreach ($event in $Events) {
    if ($event.Role -ne 'tool' -or $event.Type -notmatch 'result|complete|error|task_log') { continue }
    $callId = [string](Get-FailureProperty $event 'CallId')
    $identity = if ($callId) { "$callId`n$($event.Type)`n$($event.Text)" } else { '' }
    if ($identity -and $seenExecutions.ContainsKey($identity)) { continue }
    if ($identity) { $seenExecutions[$identity] = $true }
    foreach ($investigation in @(Invoke-Investigator -Event $event -OperationalLogPaths $OperationalLogPaths)) {
      $matched = $false
      foreach ($pattern in $patterns) {
        if ($investigation.Evidence -match $pattern.Pattern) {
          $matched = $true
          $investigation | Select-Object *, @{n='Category';e={$pattern.Name}}, @{n='Advice';e={$pattern.Advice}}
        }
      }
      if (-not $matched) {
        $investigation | Select-Object *, @{n='Category';e={'Unclassified tool failure'}}, @{n='Advice';e={'Inspect the cited runtime evidence; no catalog root cause is established.'}}
      }
    }
  }
}

function Get-FailureLifecycleSection {
  [CmdletBinding()]
  param([int]$Number, [object]$Store, [string]$Action, [string]$DiagnosticPath)
  if ($Number -eq 0) { return 'Unavailable: no explicit item reference was found in the selected conversation.' }
  $proposals = @($Store.proposals | Where-Object { [int]$_.id -eq $Number })
  $cohorts = @((Get-FailureProperty $Store 'review_cohorts' @()) | Where-Object { $_.id -eq "COH-$Number" })
  if ($cohorts.Count -and $proposals.Count) {
    return "Ambiguous number $Number identifies both a proposal and COH-$Number. Declared members: $($cohorts[0].proposal_ids -join ', '). No lifecycle action or diagnosis was attempted."
  }
  if ($cohorts.Count) { return "COH-$Number; declared members: $($cohorts[0].proposal_ids -join ', '). This report does not execute cohort actions." }
  if ($proposals.Count -ne 1) { return "Unavailable: number $Number does not resolve to exactly one current proposal." }
  $proposal = $proposals[0]
  $identity = [string](Get-FailureProperty $proposal 'crp_id' (Get-FailureProperty $proposal 'cr_id'))
  if (-not $identity) { return "Unavailable: number $Number has no exact stored identity." }
  $states = @('suggested', 'in_progress', 'verified', 'in_review', 'completed', 'pushed', 'held', 'withdrawn', 'rejected', 'superseded')
  if ($proposal.state -notin $states) { return "Unavailable: $identity has unsupported state '$($proposal.state)'." }
  $validActions = @(Get-LcmProposalLifecycleActions -State $proposal.state)
  if ($Action -in $validActions) {
    return "$identity is $($proposal.state). Action '$Action' is valid; no lifecycle failure. No action was executed."
  }
  $output = @(& $DiagnosticPath -Action $Action -TargetExpression $identity)
  @($output | Where-Object { $_ -is [string] })
}

function New-FailureMarkdown {
  [CmdletBinding()]
  param(
    [object]$Selection, [AllowEmptyCollection()][object[]]$Findings, [string]$HostName,
    [string]$SessionId, [string]$Source, [string[]]$Lifecycle, [string[]]$Actions,
    [string[]]$Limitations, [DateTimeOffset]$GeneratedAt
  )
  $producer = Get-FailureAnalysisProducer
  $lines = [Collections.Generic.List[string]]::new()
  foreach ($line in @(
    '# Catalog of Execution Errors & Failure Modes', '',
    "Generator: $($producer.Name)", "Version: $($producer.Version)",
    "Generated: $($GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    "Host: $HostName", "Session: $SessionId", "Source: $Source", '',
    '## Summary', '',
    "- Confirmed runtime failure findings: $(@($Findings | Where-Object Disposition -EQ 'Confirmed runtime failure').Count).",
    "- Unresolved evidence (not counted as confirmed errors): $(@($Findings | Where-Object Disposition -EQ 'Unresolved evidence').Count).",
    "- Selected transcript events: $($Selection.Events.Count).",
    "- Item number: $($Selection.Number) (0 means unavailable).",
    "- Anchor matches: $($Selection.Matches); the latest match is selected when repeated.",
    "- Lifecycle: $($Lifecycle -join ' ')",
    "- Recent action output lines: $($Actions.Count).",
    "- Coverage limitations: $($Limitations -join ' ')", '',
    '## Evidence boundaries', ''
  )) { $lines.Add($line) }
  $lines.Add("Anchor: $($Selection.Anchor)")
  if ($Selection.Events.Count) {
    $first = $Selection.Events[0]; $last = $Selection.Events[-1]
    $lines.Add("From event $($first.Index) / $($first.Id) through event $($last.Index) / $($last.Id).")
  }
  $lines.Add('')
  $lines.Add('## Observed failures')
  $lines.Add('')
  $lines.Add('Pattern matches are symptoms. Historical root causes are hypotheses, not verified explanations for this run.')
  if (-not @($Findings | Where-Object Disposition -EQ 'Confirmed runtime failure').Count) { $lines.Add('No confirmed tool failures were found in the available evidence; this is not proof of error-free execution.') }
  foreach ($finding in @($Findings | Where-Object Disposition -EQ 'Confirmed runtime failure')) {
    $lines.Add('')
    $lines.Add("### $($finding.Category)")
    $lines.Add("Source: $($finding.Source)")
    if ($finding.Timestamp) { $lines.Add("Recorded native event time (not filesystem time): $($finding.Timestamp)") }
    $lines.Add("Call ID: $($finding.CallId); exit status: $($finding.ExitStatus)")
    if ($null -ne $finding.Command) { $lines.Add("Arguments: $($finding.Command | ConvertTo-Json -Depth 20 -Compress)") }
    $lines.Add('````text')
    $lines.Add(($finding.Evidence -replace '`', "'"))
    $lines.Add('````')
    $lines.Add('Numbered output context (nearby text is not a backtrace):')
    $lines.Add('````text')
    $lines.Add((($finding.Context -join "`r`n") -replace '`', "'"))
    $lines.Add('````')
    $lines.Add("Runtime location/stack excerpts: $(if ($finding.Locations.Count) { $finding.Locations -join '; ' } else { 'Not available in cited context.' })")
    $lines.Add("Complementary logs: $(if ($finding.Related.Count) { $finding.Related -join '; ' } else { 'No exact diagnostic-text corroboration in supplied logs; no causal correlation established.' })")
    $lines.Add("Investigation / countermeasure: $($finding.Advice)")
  }
  $lines.Add('')
  $lines.Add('## Unresolved evidence (not confirmed errors)')
  foreach ($finding in @($Findings | Where-Object Disposition -EQ 'Unresolved evidence')) {
    $lines.Add("- $($finding.Source): $($finding.Evidence) [No failing execution status; inspect source before attributing a failure.]")
    $lines.Add('````text')
    $lines.Add((($finding.Context -join "`r`n") -replace '`', "'"))
    $lines.Add('````')
  }
  $lines.Add('')
  $lines.Add('## Execution flow and recorded purpose')
  $lines.Add('Includes successful and unknown executions. Success does not establish appropriateness; purpose does not establish authorization. No hidden reasoning is inferred.')
  $flow = @(Get-FailureExecutionFlow -Events $Selection.Events)
  if (-not $flow.Count) { $lines.Add('No tool-start metadata available in selected scope.') }
  foreach ($entry in $flow) {
    $lines.Add('')
    $lines.Add("### Tool: $($entry.Tool)")
    $lines.Add("Source: $($entry.Source)")
    $lines.Add("Call ID: $($entry.CallId); turn ID: $($entry.TurnId); parent event ID: $($entry.ParentId)")
    $lines.Add("Link strength: $($entry.Relationship)")
    $lines.Add("Outcome: $($entry.Outcome)")
    $lines.Add('````text')
    $details = "User request/context: $($entry.Request)`r`nRecorded stated purpose: $($entry.Purpose)`r`nAssistant context: $($entry.AssistantContext)`r`nArguments: $($entry.Arguments | ConvertTo-Json -Depth 20 -Compress)"
    $lines.Add(($details -replace '`', "'"))
    $lines.Add('````')
  }
  $lines.Add('')
  $lines.Add('## Catalog category coverage')
  foreach ($pattern in @(Get-FailurePatterns)) {
    $count = @($Findings | Where-Object Category -EQ $pattern.Name).Count
    $lines.Add("- $($pattern.Name): $count finding(s). $($pattern.Advice)")
  }
  foreach ($line in @('', '## Lifecycle diagnostics (read-only)', '') + $Lifecycle + @(
    '', '## Recent workspace actions (Show-Actions.ps1)', '',
    "Collected: $($GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    'These are recent workspace logs, not automatically attributable to the selected conversation.',
    'Reader sources: LCM_Inventory/data/logs/lcm (including actions.jsonl), LCM_Inventory/data/logs/lcm-internal, and workspace tools/logs.',
    '````text'
  ) + $Actions + @('````', '', '## Limitations', '') + $Limitations) { $lines.Add($line) }
  return ((($lines -join "`r`n") + "`r`n") -replace '\r?\n', "`r`n")
}

function New-FailureStructuredEvidence {
  [CmdletBinding()]
  param(
    [object]$Selection, [AllowEmptyCollection()][object[]]$Findings, [string]$HostName,
    [string]$SessionId, [string]$Source, [string[]]$Lifecycle, [string[]]$Actions,
    [string[]]$Limitations, [DateTimeOffset]$GeneratedAt
  )
  $producer = Get-FailureAnalysisProducer
  $events = @(foreach ($event in $Selection.Events) {
    [ordered]@{
      Index = Get-FailureProperty $event 'Index' 0
      Id = Get-FailureProperty $event 'Id'
      Timestamp = Get-FailureProperty $event 'Timestamp'
      Role = Get-FailureProperty $event 'Role'
      Type = Get-FailureProperty $event 'Type'
      Tool = Get-FailureProperty $event 'Tool'
      Text = Get-FailureProperty $event 'Text'
      Failed = Get-FailureProperty $event 'Failed' $false
      KnownSuccess = Get-FailureProperty $event 'KnownSuccess' $false
      CallId = Get-FailureProperty $event 'CallId'
      TurnId = Get-FailureProperty $event 'TurnId'
      ParentId = Get-FailureProperty $event 'ParentId'
      Arguments = Get-FailureProperty $event 'Arguments' $null
      ToolTitle = Get-FailureProperty $event 'ToolTitle'
      Source = Get-FailureProperty $event 'Source'
    }
  })
  $confirmed = @($Findings | Where-Object Disposition -EQ 'Confirmed runtime failure').Count
  $unresolved = @($Findings | Where-Object Disposition -EQ 'Unresolved evidence').Count
  [pscustomobject][ordered]@{
    Schema = 'LCM.FailureAnalysis'
    SchemaVersion = 1
    Producer = $producer.Name
    ProducerVersion = $producer.Version
    GeneratedAt = $GeneratedAt.ToString('o')
    Host = $HostName
    SessionId = $SessionId
    Source = $Source
    Summary = [ordered]@{
      Confirmed = $confirmed
      Unresolved = $unresolved
      EventCount = $events.Count
      Number = $Selection.Number
      AnchorMatches = $Selection.Matches
    }
    Selection = [ordered]@{
      Anchor = $Selection.Anchor
      Number = $Selection.Number
      Matches = $Selection.Matches
    }
    Events = $events
    Findings = @($Findings)
    ExecutionFlow = @(Get-FailureExecutionFlow -Events $Selection.Events)
    Lifecycle = @($Lifecycle)
    Actions = @($Actions)
    Limitations = @($Limitations)
  }
}

function Write-FailureReportPair {
  [CmdletBinding()]
  param(
    [string]$Directory, [DateTimeOffset]$GeneratedAt, [string]$Markdown,
    [object]$Evidence
  )
  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
    throw "Report directory does not exist: $Directory"
  }
  $stem = "Catalog-of-Errors-and-Failure-Modes-$($GeneratedAt.ToString('yyyyMMdd-HHmmss'))"
  $markdownPath = Join-Path $Directory "$stem.md"
  $jsonPath = Join-Path $Directory "$stem.json"
  $baseStem = $stem
  while ((Test-Path -LiteralPath $markdownPath) -or (Test-Path -LiteralPath $jsonPath)) {
    $stem = "$baseStem-$([guid]::NewGuid().ToString('N'))"
    $markdownPath = Join-Path $Directory "$stem.md"
    $jsonPath = Join-Path $Directory "$stem.json"
  }
  $json = $Evidence | ConvertTo-Json -Depth 100
  $created = [Collections.Generic.List[string]]::new()
  try {
    foreach ($item in @(
      [pscustomobject]@{ Path = $markdownPath; Content = $Markdown }
      [pscustomobject]@{ Path = $jsonPath; Content = $json }
    )) {
      $stream = [IO.File]::Open($item.Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
      try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($item.Content)
        $stream.Write($bytes, 0, $bytes.Length)
      } finally { $stream.Dispose() }
      $created.Add($item.Path)
    }
  } catch {
    foreach ($path in $created) {
      if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
    throw
  }
  [pscustomobject]@{ MarkdownPath = $markdownPath; JsonPath = $jsonPath }
}

function Write-FailureMarkdown {
  [CmdletBinding()]
  param([string]$Directory, [DateTimeOffset]$GeneratedAt, [string]$Markdown)
  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw "Report directory does not exist: $Directory" }
  $stem = "Catalog-of-Errors-and-Failure-Modes-$($GeneratedAt.ToString('yyyyMMdd-HHmmss'))"
  $path = Join-Path $Directory "$stem.md"
  if (Test-Path -LiteralPath $path) { $path = Join-Path $Directory "$stem-$([guid]::NewGuid().ToString('N')).md" }
  $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
  try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Markdown)
    $stream.Write($bytes, 0, $bytes.Length)
  } finally { $stream.Dispose() }
  return $path
}

Export-ModuleMember -Function Get-FailureAnalysisProducer, Read-FailureTranscript, Select-FailureEvidence, Invoke-Investigator, Get-FailureExecutionFlow, Find-FailureEvidence, Get-FailureLifecycleSection, New-FailureMarkdown, New-FailureStructuredEvidence, Write-FailureMarkdown, Write-FailureReportPair
