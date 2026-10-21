<#
.SYNOPSIS
  Generates a timestamped session error catalog with lifecycle and action diagnostics.
.DESCRIPTION
  Module: Invoke-FailureModeAnalysis
  Purpose: Analyzes observed tool failures from the active Copilot or Antigravity
           session, without applying lifecycle actions or altering the source catalog.
  Path: LCM_Inventory/tools/Invoke-FailureModeAnalysis.ps1
  Authors: Rolf, Copilot
  Version: 10.0.0
  Date: 2026-10-21
.PARAMETER Number
  Bare item number whose latest explicit conversation reference is the start anchor.
.PARAMETER From
  Literal user-input text. The latest matching message is the start anchor.
.PARAMETER TranscriptPath
  Offline JSON/JSONL transcript, including native Copilot events or normalized events.
.PARAMETER OutputDirectory
  Report directory; defaults to the original catalog's directory.
.PARAMETER TaskLogDirectory
  Optional explicit Antigravity task-log directory for offline analysis.
.EXAMPLE
  AnalyzeFailures -Number 300
.EXAMPLE
  AnalyzeFailures -MatchText 'review successful and accepted'
#>
[CmdletBinding(DefaultParameterSetName = 'Number')]
param(
  [Parameter(ParameterSetName = 'Number', Position = 0)]
  [Alias('CRP')]
  [ValidateRange(1, [int]::MaxValue)]
  [int]$Number,
  [Parameter(ParameterSetName = 'Text')]
  [Alias('MatchText')]
  [ValidateNotNullOrEmpty()]
  [string]$From,
  [string]$Action = 'do',
  [string]$TranscriptPath,
  [string]$TaskLogDirectory,
  [string]$OutputDirectory,
  [ValidateRange(1, 100)]
  [int]$ActionCount = 5,
  [Alias('h', '?')]
  [switch]$Help
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptVersion = '10.0.0'
if ($Help) {
  Write-Host "Invoke-FailureModeAnalysis.ps1 v$scriptVersion"
  Write-Host 'AnalyzeFailures [-Number <n> | -From <literal user input>] [-Action do]'
  Write-Host '  No selector: use the last explicit item reference in the active host session.'
  Write-Host '  Offline: -TranscriptPath <JSON/JSONL> [-TaskLogDirectory <path>]'
  Write-Host '  Reports: [-OutputDirectory <directory>] [-ActionCount <1..100>]'
  Write-Host '  Missing requested anchors stop; valid lifecycle actions are never executed.'
  return
}
$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
Import-Module -Name (Join-Path $inventoryRoot 'modules\FailureModeAnalysis.psm1') -Force
Import-Module -Name (Join-Path $inventoryRoot 'modules\ProposalManager.psm1') -Force
$generatedAt = [DateTimeOffset]::Now
$temporaryPath = $null
$hostName = 'Offline'
$sessionId = 'explicit transcript'
$limitations = [Collections.Generic.List[string]]::new()
try {
  if (-not $TranscriptPath) {
    $copilot = -not [string]::IsNullOrWhiteSpace($env:COPILOT_AGENT_SESSION_ID)
    $antigravity = -not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_CONVERSATION_ID) -or $env:ANTIGRAVITY_AGENT -eq '1'
    if ($antigravity -and (!$copilot -or $env:ANTIGRAVITY_AGENT -eq '1')) {
      $hostName = 'Antigravity'
      $sessionId = $env:ANTIGRAVITY_CONVERSATION_ID
    } elseif ($copilot -and (!$antigravity -or $env:ANTIGRAVITY_AGENT -ne '1')) {
      $hostName = 'Copilot'
      $sessionId = $env:COPILOT_AGENT_SESSION_ID
    } else {
      throw 'No active host session is identified. Supply -TranscriptPath for offline analysis.'
    }
    $providerPath = "D:\OneDrive\cmd\Export-${hostName}ReasoningTranscript.ps1"
    $temporaryPath = Join-Path ([IO.Path]::GetTempPath()) "FailureModeAnalysis-$([guid]::NewGuid().ToString('N')).jsonl"
    & $providerPath -SessionId $sessionId -OutputPath $temporaryPath
    $TranscriptPath = $temporaryPath
    if ($hostName -eq 'Copilot') {
      $homePath = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE '.copilot' }
      # The normalized exporter omits tool-result bodies; read the same selected session's native events.
      $TranscriptPath = Join-Path $homePath "session-state\$sessionId\events.jsonl"
    } else {
      $homePath = if ($env:ANTIGRAVITY_HOME) { $env:ANTIGRAVITY_HOME } else { Join-Path $env:USERPROFILE '.gemini\antigravity-ide' }
      if (-not $TaskLogDirectory) { $TaskLogDirectory = Join-Path $homePath "brain\$sessionId\.system_generated\tasks" }
      $limitations.Add('Antigravity provider timestamps may be export times, not original event times; native task logs supply additional error evidence.')
    }
  }
  $events = @(Read-FailureTranscript -Path $TranscriptPath)
  if ($temporaryPath -and $TranscriptPath -eq $temporaryPath) {
    foreach ($event in $events) { $event.Source = "$hostName session $sessionId / event $($event.Index) / $($event.Id)" }
  }
  $selection = Select-FailureEvidence -Events $events -Number $Number -From $From
  $evidence = @($selection.Events)
  if ($TaskLogDirectory) {
    if (Test-Path -LiteralPath $TaskLogDirectory -PathType Container) {
      foreach ($file in @(Get-ChildItem -LiteralPath $TaskLogDirectory -Filter 'task-*.log' -File | Sort-Object Name)) {
        $evidence += [pscustomobject]@{
          Role = 'tool'; Type = 'task_log'; Failed = $false
          Text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
          Source = $file.FullName; Timestamp = $file.LastWriteTime.ToString('o')
        }
      }
      $limitations.Add('Task logs are scoped to the selected session, not necessarily the quoted-message boundary; filesystem times are not execution timestamps.')
    } else {
      $limitations.Add("Optional task-log directory is unavailable: $TaskLogDirectory")
    }
  }
  $limitations.Add('Only available tool-result evidence is classified; user/assistant claims and commands alone do not prove a failure. Missing tool bodies limit coverage, especially IDE-buffer symptoms.')
  $findings = @(Find-FailureEvidence -Events $evidence)
  $lifecycle = @(Get-FailureLifecycleSection -Number $selection.Number -Store (Get-ProposalStore) -Action $Action -DiagnosticPath (Join-Path $PSScriptRoot 'Show-LcmFailureDiagnostic.ps1'))
  $actions = @(& (Join-Path $PSScriptRoot 'Show-Actions.ps1') -Count $ActionCount 6>&1 | ForEach-Object { [string]$_ })
  $source = if ($temporaryPath -and $TranscriptPath -eq $temporaryPath) { "$hostName session $sessionId via $providerPath" } else { $TranscriptPath }
  $markdown = New-FailureMarkdown -Selection $selection -Findings $findings -HostName $hostName -SessionId $sessionId -Source $source -Lifecycle $lifecycle -Actions $actions -Limitations $limitations.ToArray() -GeneratedAt $generatedAt
  if (-not $OutputDirectory) { $OutputDirectory = Join-Path $workspaceRoot 'LCM_AI\docs\Optimizations' }
  $path = Write-FailureMarkdown -Directory $OutputDirectory -GeneratedAt $generatedAt -Markdown $markdown
  Write-Host "Invoke-FailureModeAnalysis.ps1 v$scriptVersion : $($findings.Count) finding(s). Report: $path"
  [pscustomobject]@{ ReportPath = $path; Version = $scriptVersion; Findings = $findings.Count; Number = $selection.Number }
} finally {
  if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath)) { Remove-Item -LiteralPath $temporaryPath -Force }
}
