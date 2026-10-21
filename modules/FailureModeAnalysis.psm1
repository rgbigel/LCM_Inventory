<#
.SYNOPSIS
  Evidence selection and Markdown rendering for session failure analysis.
.NOTES
  Module: FailureModeAnalysis
  Path: LCM_Inventory/modules/FailureModeAnalysis.psm1
  Authors: Rolf, Copilot
  Version: 10.0.0
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

function Read-FailureTranscript {
  [CmdletBinding()]
  param([string]$Path)
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { throw "Transcript is empty: $Path" }
  if ([IO.Path]::GetExtension($Path) -ieq '.jsonl') {
    $items = @(foreach ($line in ($raw -split '\r?\n')) {
      if (-not [string]::IsNullOrWhiteSpace($line)) { $line | ConvertFrom-Json -ErrorAction Stop }
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
    $callId = [string](Get-FailureProperty $data 'toolCallId')
    if ($type -eq 'tool.execution_start' -and $callId) {
      $toolNames[$callId] = [string](Get-FailureProperty $data 'toolName')
    }
    $toolName = if ($callId -and $toolNames.ContainsKey($callId)) { $toolNames[$callId] } else { [string](Get-FailureProperty $item 'tool_name') }
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
    $failed = $failed -or (Get-FailureProperty $data 'isError' $false) -eq $true
    $resultValue = Get-FailureProperty $data 'result' $null
    $failed = $failed -or (Get-FailureProperty $resultValue 'isError' $false) -eq $true
    if ($role -eq 'tool' -and $type -eq 'tool_result' -and $content -match '^Tool execution completed\. Success: False\s*$') { $failed = $true }
    $time = Get-FailureProperty $item 'timestamp'
    $timeText = if ($time -is [datetime] -or $time -is [DateTimeOffset]) { $time.ToString('o') } else { [string]$time }
    [pscustomobject]@{
      Index = $index
      Id = [string](Get-FailureProperty $item 'id' "event-$index")
      Timestamp = $timeText
      Role = $role
      Type = $type
      Tool = $toolName
      Text = $content
      Failed = $failed
      KnownSuccess = (Get-FailureProperty $data 'success' $null) -eq $true
      Source = "$Path (event $index)"
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

function Find-FailureEvidence {
  [CmdletBinding()]
  param([AllowEmptyCollection()][object[]]$Events)
  $patterns = @(Get-FailurePatterns)
  foreach ($event in $Events) {
    if ($event.Role -ne 'tool' -or $event.Type -notmatch 'result|complete|error|task_log') { continue }
    $text = $event.Text -replace '\x1b\[[0-9;]*m', ''
    if ((Get-FailureProperty $event 'KnownSuccess' $false) -and -not $event.Failed) {
      if ((Get-FailureProperty $event 'Tool') -notmatch '(?i)(?:^|[._])(?:powershell|bash|shell|run_shell)$') { continue }
      $exits = @([regex]::Matches($text, '(?im)^<shellId:[^\r\n]*completed with exit code (?<code>-?\d+)>\s*$|^Process exited with code (?<code>-?\d+)\s*$'))
      if (-not $exits.Count -or [int]$exits[-1].Groups['code'].Value -eq 0) { continue }
    }
    $failureMarker = '(?im)\[ERROR\]|Status\s*:\s*FAILED|(?:exit(?:ed with)?(?: code|code)?[:\s]+|exit code )(-?[1-9]\d*)\b|Exception:|FullyQualifiedErrorId|Error:'
    if (-not $event.Failed -and $text -notmatch $failureMarker) { continue }
    $matched = $false
    foreach ($pattern in $patterns) {
      $hits = @([regex]::Matches($text, "(?im)^.*(?:$($pattern.Pattern)).*$"))
      foreach ($hit in $hits) {
        $matched = $true
        [pscustomobject]@{
          Category = $pattern.Name; Evidence = $hit.Value.Trim(); Source = $event.Source
          Timestamp = $event.Timestamp; Advice = $pattern.Advice
        }
      }
    }
    if (-not $matched) {
      $lines = @($text -split '\r?\n' | Where-Object { $_ -match $failureMarker })
      $excerpt = if ($lines.Count) { $lines[0] } elseif ($text) { $text } else { 'Tool reported failure without an error body.' }
      [pscustomobject]@{
        Category = 'Unclassified tool failure'; Evidence = $excerpt; Source = $event.Source
        Timestamp = $event.Timestamp; Advice = 'Inspect the cited tool result; no catalog root cause is established.'
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
  $lines = [Collections.Generic.List[string]]::new()
  foreach ($line in @(
    '# Catalog of Execution Errors & Failure Modes', '',
    'Generator: Invoke-FailureModeAnalysis.ps1', 'Version: 10.0.0',
    "Generated: $($GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    "Host: $HostName", "Session: $SessionId", "Source: $Source", '',
    '## Summary', '',
    "- Observed failure findings: $($Findings.Count).",
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
    $lines.Add("From event $($first.Index) / $($first.Id) ($($first.Timestamp)) through event $($last.Index) / $($last.Id) ($($last.Timestamp)).")
  }
  $lines.Add('')
  $lines.Add('## Observed failures')
  $lines.Add('')
  $lines.Add('Pattern matches are symptoms. Historical root causes are hypotheses, not verified explanations for this run.')
  if (-not $Findings.Count) { $lines.Add('No matching tool failures were found in the available evidence; this is not proof of error-free execution.') }
  foreach ($finding in $Findings) {
    $lines.Add('')
    $lines.Add("### $($finding.Category)")
    $lines.Add("Source: $($finding.Source); time: $($finding.Timestamp)")
    $lines.Add('````text')
    $lines.Add(($finding.Evidence -replace '`', "'"))
    $lines.Add('````')
    $lines.Add("Investigation / countermeasure: $($finding.Advice)")
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

Export-ModuleMember -Function Read-FailureTranscript, Select-FailureEvidence, Find-FailureEvidence, Get-FailureLifecycleSection, New-FailureMarkdown, Write-FailureMarkdown
