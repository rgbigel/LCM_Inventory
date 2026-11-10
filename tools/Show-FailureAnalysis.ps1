<#
.SYNOPSIS
  Serves a retained failure-analysis snapshot through the LCM desktop daemon.
.DESCRIPTION
  Opens an exact Markdown or JSON report, or the newest retained failure-analysis
  report, without recollecting session evidence.
.NOTES
  Module: Show-FailureAnalysis
  Purpose: Prepares and opens retained failure-analysis snapshots through the LCM daemon.
  Path: LCM_Inventory/tools/Show-FailureAnalysis.ps1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-11-08 17:34:00
.PARAMETER ReportPath
  Exact retained Markdown or structured JSON report to display.
.PARAMETER NoLaunch
  Creates the retained snapshot without opening the browser.
.PARAMETER Pane
  Opens the display inside an Antigravity IDE editor/side pane instead of an external browser window (Alias: -Panel).
.PARAMETER SnapshotRoot
  Optional snapshot root; defaults to data\artifacts\failure-analysis.
.PARAMETER ShowAll
  Emits each structured audit record to the host. Detailed is an alias.
.PARAMETER LogFile
  Optional JSONL audit path; defaults to a unique file in the inventory logs directory.
.EXAMPLE
  ShowFailureAnalysis
.EXAMPLE
  ShowFailureAnalysis -ReportPath 'D:\reports\Catalog-of-Errors-and-Failure-Modes-20261021-220000.md' -NoLaunch
#>
[CmdletBinding()]
param(
  [string]$ReportPath,
  [string]$SnapshotRoot,
  [switch]$NoLaunch,
  [Parameter(Mandatory = $false, HelpMessage = 'Opens the display inside an Antigravity IDE editor/side pane')]
  [Alias('Panel')]
  [switch]$Pane,
  [Alias('Detailed')]
  [switch]$ShowAll,
  [string]$LogFile,
  [Alias('h', '?')]
  [switch]$Help
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'ShowFailureAnalysis [-ReportPath <exact .md or .json>] [-NoLaunch] [-SnapshotRoot <directory>] [-ShowAll|-Detailed] [-LogFile <JSONL path>]'
  Write-Host 'With no report path, selects the newest retained failure-analysis report.'
  Write-Host 'The viewer never reruns analysis and only opens an HTTP loopback daemon route.'
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
$toolName = 'Show-FailureAnalysis.ps1'
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmDisplayVersion.psm1') -Force
$toolVersion = Get-LcmDisplaySourceVersion -Path $PSCommandPath
$startedAt = [DateTimeOffset]::Now
$status = 'Failed'
$auditError = ''
$snapshotId = $null
if (-not $LogFile) {
  $LogFile = Join-Path $inventoryRoot "logs\Show-FailureAnalysis-$($startedAt.ToString('yyyyMMdd-HHmmss'))-$([guid]::NewGuid().ToString('N')).jsonl"
}
$LogFile = [IO.Path]::GetFullPath($LogFile)
$logDirectory = Split-Path $LogFile -Parent
if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
  New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
function Write-FailureViewerAudit {
  [CmdletBinding()]
  param([Alias('Event')][string]$AuditEvent, [string]$State, [string]$Message)
  $record = [ordered]@{
    Timestamp = [DateTimeOffset]::Now.ToString('o')
    Tool = $toolName
    Version = $toolVersion
    Event = $AuditEvent
    Status = $State
    ReportPath = $ReportPath
    SnapshotId = $snapshotId
    NoLaunch = [bool]$NoLaunch
    Message = $Message
  } | ConvertTo-Json -Compress
  [IO.File]::AppendAllText($LogFile, $record + "`r`n", [Text.UTF8Encoding]::new($false))
  if ($ShowAll) { Write-Host $record }
}
try {
Write-FailureViewerAudit -Event 'Started' -State 'Running' -Message 'Selecting retained evidence; no analysis is collected.'
$canonicalSnapshotRoot = Join-Path $inventoryRoot 'data\artifacts\failure-analysis'
if ($SnapshotRoot) {
  $requestedRoot = [IO.Path]::GetFullPath($SnapshotRoot)
  $canonicalRoot = [IO.Path]::GetFullPath($canonicalSnapshotRoot)
  if (-not $NoLaunch -and -not [string]::Equals($requestedRoot, $canonicalRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A custom SnapshotRoot requires -NoLaunch; the daemon only serves snapshots under the canonical data\artifacts\failure-analysis directory.'
  }
}
$defaultReports = Join-Path $workspaceRoot 'LCM_AI\docs\Optimizations'
if (-not $ReportPath) {
  if (-not (Test-Path -LiteralPath $defaultReports -PathType Container)) {
    throw "Failure-analysis report directory does not exist: $defaultReports"
  }
  $latest = Get-ChildItem -LiteralPath $defaultReports -File |
    Where-Object { $_.Name -match '^Catalog-of-Errors-and-Failure-Modes-\d{8}-\d{6}(?:-[a-f0-9]{32})?\.(?:md|json)$' } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if (-not $latest) { throw "No retained failure-analysis reports were found in $defaultReports" }
  $ReportPath = $latest.FullName
}
if ([IO.Path]::GetExtension($ReportPath) -notin @('.md', '.json')) {
  throw "ReportPath must identify an exact .md or .json report: $ReportPath"
}
if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
  throw "Failure-analysis report does not exist: $ReportPath"
}
$sourcePath = (Resolve-Path -LiteralPath $ReportPath).Path
$sourceExtension = [IO.Path]::GetExtension($sourcePath)
$jsonPath = if ($sourceExtension -ieq '.json') { $sourcePath } else { [IO.Path]::ChangeExtension($sourcePath, '.json') }
$markdownPath = if ($sourceExtension -ieq '.md') { $sourcePath } else { [IO.Path]::ChangeExtension($sourcePath, '.md') }
$hasJson = Test-Path -LiteralPath $jsonPath -PathType Leaf
$hasMarkdown = Test-Path -LiteralPath $markdownPath -PathType Leaf
if ($hasJson) {
  $evidence = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  if ($evidence.Schema -ne 'LCM.FailureAnalysis' -or $evidence.SchemaVersion -ne 1) {
    throw "Unsupported structured failure-analysis report schema: $jsonPath"
  }
}
if (-not $hasJson -and -not $hasMarkdown) {
  throw "No usable failure-analysis evidence found for report: $sourcePath"
}

Import-Module -Name (Join-Path $inventoryRoot 'modules\FailureAnalysisHtml.psm1') -Force -ErrorAction Stop
if (-not $SnapshotRoot) { $SnapshotRoot = $canonicalSnapshotRoot }
if (-not (Test-Path -LiteralPath $SnapshotRoot -PathType Container)) {
  New-Item -Path $SnapshotRoot -ItemType Directory -Force | Out-Null
}
do {
  $snapshotId = [guid]::NewGuid().ToString('N')
  $snapshotDirectory = Join-Path $SnapshotRoot $snapshotId
} while (Test-Path -LiteralPath $snapshotDirectory)
New-Item -Path $snapshotDirectory -ItemType Directory | Out-Null
try {
  if ($hasJson) { Copy-Item -LiteralPath $jsonPath -Destination (Join-Path $snapshotDirectory 'report.json') }
  if ($hasMarkdown) { Copy-Item -LiteralPath $markdownPath -Destination (Join-Path $snapshotDirectory 'report.md') }
  $null = Write-FailureAnalysisIndex -Path (Join-Path $snapshotDirectory 'index.html') -SnapshotId $snapshotId -HasJson:$hasJson -HasMarkdown:$hasMarkdown
} catch {
  Remove-Item -LiteralPath $snapshotDirectory -Recurse -Force -ErrorAction SilentlyContinue
  throw
}

$result = [pscustomobject]@{
  SnapshotId = $snapshotId
  SnapshotPath = $snapshotDirectory
  ReportPath = $sourcePath
  JsonPath = if ($hasJson) { Join-Path $snapshotDirectory 'report.json' } else { $null }
  MarkdownPath = if ($hasMarkdown) { Join-Path $snapshotDirectory 'report.md' } else { $null }
  Url = "http://127.0.0.1:9876/failure-analysis/$snapshotId/index.html"
  Launched = $false
}
if (-not $NoLaunch) {
  $displayModule = Join-Path $inventoryRoot 'modules\LcmStandardDisplay.psm1'
  if (-not (Test-Path -LiteralPath $displayModule -PathType Leaf)) {
    throw "Snapshot $snapshotId was retained at $snapshotDirectory, but shared display module is unavailable: $displayModule"
  }
  try {
    Import-Module -Name $displayModule -Force -ErrorAction Stop
    $displayResult = Open-LcmStandardDisplay -DisplayId failure-analysis -SnapshotId $snapshotId -Pane:$Pane -ErrorAction Stop
    if ($displayResult -is [psobject] -and $displayResult.PSObject.Properties['Success'] -and -not $displayResult.Success) {
      throw 'The shared display helper reported that the daemon route could not be opened.'
    }
    $result.Launched = $true
  } catch {
    throw "Snapshot $snapshotId was retained at $snapshotDirectory, but the HTTP loopback display failed: $($_.Exception.Message)"
  }
}
Write-Host "Failure-analysis snapshot $snapshotId retained at $snapshotDirectory"
$status = 'Succeeded'
$result
} catch {
  $auditError = $_.Exception.Message
  throw
} finally {
  $completedAt = [DateTimeOffset]::Now
  try {
    Write-FailureViewerAudit -Event 'Completed' -State $status -Message $auditError
  } catch {
    Write-Warning "Viewer audit could not be persisted: $($_.Exception.Message)"
  }
  Write-Host "[SUMMARY] Tool=$toolName Version=$toolVersion Status=$status Log=$LogFile Time=$($completedAt.ToString('o')) DurationMs=$([Math]::Round(($completedAt - $startedAt).TotalMilliseconds))"
}
