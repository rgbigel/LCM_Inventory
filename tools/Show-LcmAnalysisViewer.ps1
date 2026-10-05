<#
.SYNOPSIS
  Renders the LCM Level 1 functional documentation analysis as an interactive HTML dashboard.
.DESCRIPTION
  Module: Show-LcmAnalysisViewer
  Purpose: Loads retained CON analysis evidence from data\analysis, writes a searchable
           and sortable LCM-standard HTML viewer, and optionally opens it.
  Path: tools/Show-LcmAnalysisViewer.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.5.0
  Date: 2026-10-05
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Path to the Level 1 JSON evidence report.')]
  [string]$ReportPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Path for the generated interactive HTML viewer.')]
  [string]$OutputPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Path to derived caller-intent reconciliation evidence.')]
  [string]$ReconciliationPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'VS Code URI scheme used by source-location links.')]
  [ValidateSet('Auto', 'vscode', 'vscode-insiders')]
  [string]$EditorUriScheme = 'Auto',

  [Parameter(Mandatory = $false, HelpMessage = 'Generate the HTML viewer without launching it.')]
  [switch]$NoLaunch,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '1.5.0'
$scriptName = 'Show-LcmAnalysisViewer'

if ($Help) {
  Write-Host '=========================================================================='
  Write-Host " LCM ANALYSIS VIEWER (v$scriptVersion)"
  Write-Host '=========================================================================='
  Write-Host 'SYNOPSIS:'
  Write-Host '  Renders retained CON analysis JSON evidence as an interactive HTML dashboard.'
  Write-Host ''
  Write-Host 'USAGE:'
  Write-Host '  pwsh tools/Show-LcmAnalysisViewer.ps1 [-ReportPath <path>] [-OutputPath <path>]'
  Write-Host '    [-ReconciliationPath <path>] [-NoLaunch] [-h]'
  Write-Host ''
  Write-Host 'DEFAULTS:'
  Write-Host '  Input : data\analysis\CON-001-L01-R002.json'
  Write-Host '  Output: data\artifacts\CON-001-L01-R002.html'
  Write-Host ''
  Write-Host 'INTERACTION:'
  Write-Host '  Filter by repository, functional element type, check outcome, or text.'
  Write-Host '  Select a source row to open its file and line in VS Code/Antigravity.'
  Write-Host '=========================================================================='
  return
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$analysisDirectory = Join-Path $repositoryRoot 'data\analysis'
$historyDirectory = Join-Path $analysisDirectory 'history'
$artifactDirectory = Join-Path $repositoryRoot 'data\artifacts'
$logDirectory = Join-Path $repositoryRoot 'data\logs\lcm'
$null = New-Item -ItemType Directory -Path $analysisDirectory -Force
$null = New-Item -ItemType Directory -Path $artifactDirectory -Force
$null = New-Item -ItemType Directory -Path $logDirectory -Force

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $latestReport = Get-ChildItem -LiteralPath $historyDirectory -File |
    Where-Object { $_.Name -match '^CON-\d+-L\d+-R\d{3}\.json$' } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if ($null -eq $latestReport) {
    throw "No CON analysis evidence report was found in $analysisDirectory"
  }
  $ReportPath = $latestReport.FullName
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $artifactDirectory ((Split-Path -Path $ReportPath -LeafBase) + '.html')
}

function Write-AnalysisLog {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [ValidateSet('INFO', 'PASS', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )

  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -LiteralPath $logPath -Value "[$timestamp] [$Level] $Message" -Encoding utf8
}

function ConvertTo-HtmlSafe {
  param(
    [AllowNull()]
    [object]$Value
  )

  return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-PropertyValue {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Object,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Default = ''
  )

  if ($Object.PSObject.Properties[$Name]) {
    return [string]$Object.$Name
  }

  return $Default
}

$logPath = Join-Path $logDirectory "$scriptName-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Write-AnalysisLog -Message "Loading Level 1 report from $ReportPath."

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
  throw "Level 1 JSON evidence report not found: $ReportPath"
}

try {
  $report = Get-Content -LiteralPath $ReportPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
} catch {
  throw "Level 1 JSON evidence report could not be parsed: $($_.Exception.Message)"
}

if (-not $report.PSObject.Properties['elements']) {
  throw "Level 1 JSON evidence report has no 'elements' collection: $ReportPath"
}

$elements = @($report.elements)
$baselineRunId = Get-PropertyValue -Object $report -Name 'run_id'
if ([string]::IsNullOrWhiteSpace($ReconciliationPath)) {
  $candidateReconciliationPath = Join-Path $historyDirectory ((Split-Path -Path $ReportPath -LeafBase) + '-S020-CallerIntentReconciliation.json')
  if (Test-Path -LiteralPath $candidateReconciliationPath -PathType Leaf) {
    $ReconciliationPath = $candidateReconciliationPath
  }
}

$reconciliation = $null
if (-not [string]::IsNullOrWhiteSpace($ReconciliationPath)) {
  if (-not (Test-Path -LiteralPath $ReconciliationPath -PathType Leaf)) {
    throw "Caller-intent reconciliation evidence was not found: $ReconciliationPath"
  }
  $reconciliation = Get-Content -LiteralPath $ReconciliationPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
  if ($reconciliation.baseline_run_id -ne $baselineRunId) {
    throw "Caller-intent reconciliation baseline '$($reconciliation.baseline_run_id)' does not match report '$baselineRunId'."
  }
}

$reconciliationByLocation = @{}
if ($reconciliation) {
  foreach ($record in @($reconciliation.records)) {
    $key = '{0}:{1}' -f $record.baseline_source_file, $record.baseline_line
    $reconciliationByLocation[$key] = $record
  }
}

$check0 = if ($report.PSObject.Properties['step0_rule_baseline']) { $report.step0_rule_baseline } else { $null }
$check0Status = if ($check0) { Get-PropertyValue -Object $check0 -Name 'check0' -Default 'Check 0: not found' } else { 'Check 0: not found' }
$workspaceRoot = 'D:\Git_Repositories\'
$legacyMatchCount = @($elements | Where-Object {
    $_.check1 -eq 'OK' -or $_.check2 -eq 'OK' -or $_.check3 -eq 'OK' -or $_.check4 -eq 'OK'
  }).Count
$refinementSummary = if ($report.PSObject.Properties['refinement_summary']) { $report.refinement_summary } else { $null }
$publicParameterGateCount = if ($refinementSummary) { [int]$refinementSummary.public_parameter_gates } else { 0 }
$undocumentedParameterGateCount = if ($refinementSummary) { [int]$refinementSummary.undocumented_parameter_gates } else { 0 }
$internalControlFlowCount = if ($refinementSummary) { [int]$refinementSummary.internal_control_flow } else { 0 }
$directDocumentedCount = if ($refinementSummary) { [int]$refinementSummary.documented_parameter_gates } else { 0 }
$callerContextDocumentedCount = if ($reconciliation) { [int]$reconciliation.statistics.caller_context_documented } else { 0 }
$totalDocumentedCount = if ($reconciliation) { [int]$reconciliation.statistics.total_documented } else { $directDocumentedCount }
$remainingUnresolvedCount = if ($reconciliation) { [int]$reconciliation.statistics.still_unresolved } else { $undocumentedParameterGateCount }
$powershellParameterHelpSummary = if ($report.PSObject.Properties['powershell_parameter_help_summary']) { $report.powershell_parameter_help_summary } else { $null }
$powershellParameterHelpDisplay = if ($powershellParameterHelpSummary) {
  '{0} / {1}' -f $powershellParameterHelpSummary.help_documented, $powershellParameterHelpSummary.public_parameters
} else {
  'N/A'
}
$powershellParameterHelpMissingDisplay = if ($powershellParameterHelpSummary) {
  [string]$powershellParameterHelpSummary.help_missing
} else {
  'N/A'
}
$repositoryCount = @($elements.repository | Sort-Object -Unique).Count
$resolvedEditorUriScheme = if ($EditorUriScheme -eq 'Auto') {
  if (
    $env:VSCODE_IPC_HOOK_CLI -match 'Code - Insiders' -or
    (Test-Path -LiteralPath 'Registry::HKEY_CLASSES_ROOT\vscode-insiders')
  ) {
    'vscode-insiders'
  } else {
    'vscode'
  }
} else {
  $EditorUriScheme
}

$normalizedElements = foreach ($element in $elements) {
  $sourcePath = Get-PropertyValue -Object $element -Name 'source_file'
  $line = Get-PropertyValue -Object $element -Name 'line'
  $sourceUriPath = $sourcePath.Replace('\', '/')
  $escapedSourceUriPath = [uri]::EscapeDataString($sourceUriPath).Replace('%2F', '/').Replace('%3A', ':')
  $sourceDisplay = if ($sourcePath.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $sourcePath.Substring($workspaceRoot.Length)
  } else {
    $sourcePath
  }
  $reconciliationKey = '{0}:{1}' -f $sourcePath, $line
  $reconciliationRecord = if ($reconciliationByLocation.ContainsKey($reconciliationKey)) { $reconciliationByLocation[$reconciliationKey] } else { $null }
  [pscustomobject]@{
    recordKind = 'functional-element'
    repository = Get-PropertyValue -Object $element -Name 'repository'
    source = $sourcePath
    sourceDisplay = $sourceDisplay
    sourceFile = [System.IO.Path]::GetFileName($sourcePath)
    line = [int]$line
    sourceUrl = '{0}://file/{1}:{2}:1' -f $resolvedEditorUriScheme, $escapedSourceUriPath, $line
    element = Get-PropertyValue -Object $element -Name 'element'
    type = Get-PropertyValue -Object $element -Name 'kind'
    check1 = Get-PropertyValue -Object $element -Name 'check1' -Default 'not found'
    check2 = Get-PropertyValue -Object $element -Name 'check2' -Default 'not found'
    check3 = Get-PropertyValue -Object $element -Name 'check3' -Default 'not found'
    check4 = Get-PropertyValue -Object $element -Name 'check4' -Default 'not found'
    classification = Get-PropertyValue -Object $element -Name 'classification' -Default 'named-functional-element'
    refinementStatus = Get-PropertyValue -Object $element -Name 'refinement_status' -Default 'not-applicable'
    publicParameters = @($element.public_parameters) -join ', '
    branchKind = Get-PropertyValue -Object $element -Name 'branch_kind' -Default (Get-PropertyValue -Object $element -Name 'kind')
    branchIndex = Get-PropertyValue -Object $element -Name 'branch_index'
    documentationTier = if ($reconciliationRecord) { [string]$reconciliationRecord.documentation_tier } elseif ($element.refinement_status -eq 'parameter-gate-documented') { 'direct' } else { 'none' }
    reconciliationStatus = if ($reconciliationRecord) { [string]$reconciliationRecord.reconciliation_status } else { '' }
    relevance = if ($reconciliationRecord) { [string]$reconciliationRecord.relevance } else { '' }
    confidence = if ($reconciliationRecord) { [string]$reconciliationRecord.confidence } else { '' }
    callerEvidence = if ($reconciliationRecord) { (@($reconciliationRecord.caller_evidence | ForEach-Object { "$($_.caller_symbol) ($($_.caller_file):$($_.caller_line))" }) -join '; ') } else { '' }
    helpDocumented = $null
  }
}

$repositoryBySource = @{}
foreach ($row in $normalizedElements) {
  if (-not $repositoryBySource.ContainsKey($row.source)) {
    $repositoryBySource[$row.source] = $row.repository
  }
}
$normalizedHelpRecords = if ($powershellParameterHelpSummary) {
  foreach ($helpRecord in @($powershellParameterHelpSummary.records)) {
    $helpSourcePath = [string]$helpRecord.source_file
    $helpSourceUriPath = $helpSourcePath.Replace('\', '/')
    $escapedHelpSourceUriPath = [uri]::EscapeDataString($helpSourceUriPath).Replace('%2F', '/').Replace('%3A', ':')
    $helpSourceDisplay = if ($helpSourcePath.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      $helpSourcePath.Substring($workspaceRoot.Length)
    } else {
      $helpSourcePath
    }
    [pscustomobject]@{
      recordKind = 'parameter-help'
      repository = if ($repositoryBySource.ContainsKey($helpSourcePath)) { $repositoryBySource[$helpSourcePath] } else { 'Unknown' }
      source = $helpSourcePath
      sourceDisplay = $helpSourceDisplay
      sourceFile = [System.IO.Path]::GetFileName($helpSourcePath)
      line = if ($helpRecord.help_evidence) { [int]$helpRecord.help_evidence.line } else { 0 }
      sourceUrl = if ($helpRecord.help_evidence) { '{0}://file/{1}:{2}:1' -f $resolvedEditorUriScheme, $escapedHelpSourceUriPath, $helpRecord.help_evidence.line } else { '{0}://file/{1}' -f $resolvedEditorUriScheme, $escapedHelpSourceUriPath }
      element = '.PARAMETER {0}' -f $helpRecord.parameter
      type = 'parameter-help'
      check1 = 'not applicable'
      check2 = 'not applicable'
      check3 = 'not applicable'
      check4 = 'not applicable'
      classification = 'header-help'
      refinementStatus = if ($helpRecord.help_documented) { 'parameter-help-documented' } else { 'parameter-help-missing' }
      publicParameters = [string]$helpRecord.parameter
      branchKind = 'parameter-help'
      branchIndex = $null
      documentationTier = if ($helpRecord.help_documented) { 'header-help' } else { 'none' }
      reconciliationStatus = ''
      relevance = ''
      confidence = ''
      callerEvidence = ''
      helpDocumented = [bool]$helpRecord.help_documented
    }
  }
} else {
  @()
}
$viewerRows = @($normalizedElements) + @($normalizedHelpRecords)
$payload = $viewerRows | ConvertTo-Json -Depth 4 -Compress
$payload = $payload -replace '<', '\u003c'
$payload = $payload -replace '>', '\u003e'
$runId = ConvertTo-HtmlSafe -Value (Get-PropertyValue -Object $report -Name 'run_id' -Default 'CON analysis evidence')
$title = ConvertTo-HtmlSafe -Value ("LCM Analysis Viewer - $runId")
$generatedAt = ConvertTo-HtmlSafe -Value (Get-PropertyValue -Object $report -Name 'generated_at')
$check0Display = ConvertTo-HtmlSafe -Value $check0Status
$reportDisplayPath = ConvertTo-HtmlSafe -Value $ReportPath

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <style>
    :root {
      --ink: #172127;
      --muted: #5d6b72;
      --canvas: #edf1ef;
      --surface: #ffffff;
      --surface-soft: #f6f8f7;
      --line: #ccd5d1;
      --line-strong: #aab8b2;
      --blue: #176b87;
      --blue-soft: #e0f0f4;
      --green: #2d764d;
      --green-soft: #e4f2e8;
      --amber: #9a6510;
      --amber-soft: #fff2d7;
      --red: #a53d36;
      --red-soft: #fce8e5;
      --violet: #6b4c8d;
      --violet-soft: #eee8f5;
      --topbar: #132b33;
      --topbar-text: #f4f8f6;
      --accent: #d8a840;
      --mono: "IBM Plex Mono", Consolas, monospace;
      --sans: "IBM Plex Sans", "Segoe UI", sans-serif;
    }
    :root[data-theme="dark"] {
      --ink: #e5eeeb;
      --muted: #a7b7b2;
      --canvas: #162027;
      --surface: #1e2a31;
      --surface-soft: #24333b;
      --line: #3a4a52;
      --line-strong: #55707a;
      --blue: #6bc4df;
      --blue-soft: #173b48;
      --green: #81d49a;
      --green-soft: #1d3f2a;
      --amber: #e8bc68;
      --amber-soft: #4b3d1d;
      --red: #f18b82;
      --red-soft: #4b2626;
      --violet: #c7abed;
      --violet-soft: #382c4a;
      --topbar: #101b21;
      --topbar-text: #edf6f3;
      --accent: #e4bf61;
    }
    * { box-sizing: border-box; }
    html, body { height: 100%; margin: 0; background: var(--canvas); color: var(--ink); font-family: var(--sans); }
    body { display: flex; flex-direction: column; overflow: hidden; }
    button, input, select { font: inherit; }
    button { cursor: pointer; }
    .topbar { min-height: 54px; padding: 0 24px; display: flex; align-items: center; gap: 18px; background: var(--topbar); color: var(--topbar-text); border-bottom: 3px solid var(--accent); }
    .brand strong { display: block; font-size: 15px; letter-spacing: .02em; }
    .brand span, .header-meta { color: var(--muted); font: 11px var(--mono); }
    .header-meta { color: #c9d8d4; }
    .header-actions { margin-left: auto; display: flex; gap: 6px; }
    .top-button, .reset-button { min-height: 30px; padding: 0 10px; border: 1px solid var(--line-strong); border-radius: 4px; background: var(--surface); color: var(--ink); font-size: 12px; }
    .top-button { background: transparent; color: var(--topbar-text); border-color: var(--line-strong); }
    .top-button:hover, .reset-button:hover { border-color: var(--blue); background: var(--blue-soft); }
    main { flex: 1; min-height: 0; width: min(1920px, 100%); margin: 0 auto; padding: 10px 24px 14px; display: flex; flex-direction: column; gap: 10px; }
    .control-row { display: flex; align-items: center; gap: 10px; padding: 6px 12px; background: var(--surface); border: 1px solid var(--line); border-radius: 6px; }
    .control-group { display: flex; align-items: center; gap: 6px; padding-right: 10px; border-right: 1px solid var(--line); }
    .control-group:last-child { border-right: 0; padding-right: 0; }
    .control-label { color: var(--muted); font: 11px var(--mono); text-transform: uppercase; }
    .control-input, .control-select { min-height: 30px; padding: 0 8px; border: 1px solid var(--line-strong); border-radius: 4px; background: var(--surface-soft); color: var(--ink); font-size: 12px; }
    .control-input { min-width: 320px; font-family: var(--mono); }
    .status-rail { display: grid; grid-template-columns: repeat(8, minmax(0, 1fr)); gap: 8px; }
    .metric { padding: 9px 12px; border: 1px solid var(--line); border-radius: 6px; background: var(--surface); }
    .metric-button { width: 100%; text-align: left; cursor: pointer; }
    .metric-button[data-state="include"] { border-color: var(--green); background: var(--green-soft); }
    .metric-button[data-state="exclude"] { border-color: var(--red); background: var(--red-soft); }
    .metric-button[data-state="include"] .metric-value { color: var(--green); }
    .metric-button[data-state="exclude"] .metric-value { color: var(--red); }
    .metric-label { display: block; color: var(--muted); font: 11px var(--mono); text-transform: uppercase; }
    .metric-value { display: block; margin-top: 2px; font: 600 20px var(--mono); }
    .metric.ok .metric-value { color: var(--green); } .metric.open .metric-value { color: var(--blue); } .metric.warn .metric-value { color: var(--amber); }
    .table-shell { flex: 1; min-height: 0; overflow: auto; border: 1px solid var(--line); border-radius: 6px; background: var(--surface); }
    table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 12px; }
    th { position: sticky; top: 0; z-index: 2; text-align: left; padding: 10px; background: var(--surface-soft); border-bottom: 1px solid var(--line-strong); color: var(--muted); font: 600 11px var(--mono); text-transform: uppercase; white-space: nowrap; cursor: pointer; }
    .column-filters th { top: 37px; padding: 5px 8px; cursor: default; }
    .column-filters .control-select { width: 100%; min-width: 0; }
    th:hover { color: var(--blue); } td { padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; } tr:hover td { background: var(--blue-soft); } tr:last-child td { border-bottom: 0; }
    .mono { font-family: var(--mono); } .source, .element { max-width: 420px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; } a { color: var(--blue); text-decoration: none; } a:hover { text-decoration: underline; }
    .badge { display: inline-block; padding: 2px 6px; margin: 0 3px 3px 0; border-radius: 3px; font: 10px var(--mono); background: var(--red-soft); color: var(--red); } .badge.ok { background: var(--green-soft); color: var(--green); }
    .footer { color: var(--muted); font: 11px var(--mono); }
    @media print { @page { margin: 8mm; } body { overflow: visible; } .topbar, .control-row { display: none; } main { display: block; padding: 0; } .table-shell { overflow: visible; border: 0; } thead { display: table-header-group; } tr { break-inside: avoid; } }
  </style>
</head>
<body>
  <header class="topbar">
    <div class="brand"><strong>LCM ANALYSIS VIEWER</strong><span>LEVEL 1 / FUNCTIONAL DOCUMENTATION TRACEABILITY</span></div>
    <div class="header-meta">Generated: $generatedAt</div>
    <div class="header-actions">
      <button class="top-button" id="theme-toggle" type="button">Theme</button>
      <button class="top-button" id="refresh-button" type="button">Refresh</button>
    </div>
  </header>
  <main>
    <section class="control-row">
      <div class="control-group"><span class="control-label">Find</span><input class="control-input" id="query" type="search" placeholder="repo:, source:, element:, type:, docs:, results:; AND, OR, !, (), &quot;phrase&quot;"></div>
      <button class="reset-button" id="reset-button" type="button">Reset</button>
    </section>
    <section class="status-rail">
      <button class="metric metric-button open" data-filter="functional" data-state="ignore" type="button"><span class="metric-label">Functional Elements</span><span class="metric-value" id="total-count">$($elements.Count)</span></button>
      <button class="metric metric-button ok" data-filter="direct" data-state="ignore" type="button"><span class="metric-label">Direct Documentation</span><span class="metric-value">$directDocumentedCount</span></button>
      <button class="metric metric-button ok" data-filter="caller-context" data-state="ignore" type="button"><span class="metric-label">Caller Context</span><span class="metric-value">$callerContextDocumentedCount</span></button>
      <button class="metric metric-button ok" data-filter="total-documented" data-state="ignore" type="button"><span class="metric-label">Total Documented</span><span class="metric-value">$totalDocumentedCount</span></button>
      <button class="metric metric-button warn" data-filter="unresolved" data-state="ignore" type="button"><span class="metric-label">Still Unresolved</span><span class="metric-value">$remainingUnresolvedCount</span></button>
      <button class="metric metric-button open" data-filter="header-help" data-state="ignore" type="button"><span class="metric-label">PowerShell Header/Help</span><span class="metric-value">$powershellParameterHelpDisplay</span></button>
      <button class="metric metric-button warn" data-filter="header-help-missing" data-state="ignore" type="button"><span class="metric-label">Header/Help Missing</span><span class="metric-value">$powershellParameterHelpMissingDisplay</span></button>
      <div class="metric"><span class="metric-label">Rule Baseline</span><span class="metric-value">$check0Display</span></div>
    </section>
    <section class="table-shell">
      <table>
        <thead>
          <tr><th data-key="repository" style="width: 9%;">Repo</th><th data-key="source" style="width: 22%;">Source / Location</th><th data-key="element" style="width: 25%;">Element</th><th data-key="type" style="width: 9%;">Type</th><th data-key="coverage" style="width: 12%;">Docs</th><th data-key="checks" style="width: 23%;">Results</th></tr>
        </thead>
        <tbody id="report-body"></tbody>
      </table>
    </section>
    <footer class="footer"><span id="match-count"></span> | Evidence: $reportDisplayPath | Select a source or functional element to open the associated location.</footer>
  </main>
  <script>
    const rows = $payload;
    const state = { sortKey: 'source', sortDirection: 1, metricFilters: {} };
    const esc = value => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
    const checks = row => [1, 2, 3, 4].map(index => ({ index, value: row['check' + index] || 'not found' }));
    const checkText = row => 'Refinement: ' + row.refinementStatus + '; Coverage: ' + row.documentationTier + '; Reconciliation: ' + row.reconciliationStatus + '; Classification: ' + row.classification + '; ' + checks(row).map(check => 'C' + check.index + ': ' + check.value).join('; ');
    const queryFields = row => ({
      repo: row.repository,
      source: row.sourceFile + ' ' + row.source,
      element: row.element,
      type: row.type,
      docs: row.documentationTier + ' ' + row.refinementStatus,
      results: checkText(row)
    });
    const tokenizeQuery = query => {
      const tokens = [];
      const pattern = /\s*(\(|\)|\||\+|!|(?:[A-Za-z]+:)?(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s()|+!]+)\s*/g;
      let match;
      while ((match = pattern.exec(query)) !== null) {
        tokens.push(match[1].replace(/,$/, ''));
      }
      return tokens;
    };
    const evaluateQuery = (query, row) => {
      const tokens = tokenizeQuery(query);
      if (!tokens.length) return true;
      let position = 0;
      const matchTerm = term => {
        const normalized = term.replace(/^["']|["']$/g, '').toLowerCase();
        const qualified = normalized.match(/^(repo|repository|source|element|type|docs|coverage|results|result):(.*)$/);
        const fields = queryFields(row);
        if (qualified) {
          const key = ({ repository: 'repo', coverage: 'docs', result: 'results' })[qualified[1]] || qualified[1];
          const qualifiedValue = qualified[2].replace(/^["']|["']$/g, '');
          return String(fields[key] || '').toLowerCase().includes(qualifiedValue);
        }
        return Object.values(fields).join(' ').toLowerCase().includes(normalized);
      };
      const parsePrimary = () => {
        const token = tokens[position++];
        if (token === '(') {
          const value = parseOr();
          if (tokens[position] === ')') position++;
          return value;
        }
        return token ? matchTerm(token) : true;
      };
      const parseUnary = () => {
        if (tokens[position] === '!') {
          position++;
          return !parseUnary();
        }
        if (tokens[position] && tokens[position].startsWith('!')) {
          const token = tokens[position++];
          return !matchTerm(token.slice(1));
        }
        return parsePrimary();
      };
      const parseAnd = () => {
        let value = parseUnary();
        while (position < tokens.length && tokens[position] !== ')' && tokens[position].toUpperCase() !== 'OR' && tokens[position] !== '|') {
          if (tokens[position].toUpperCase() === 'AND' || tokens[position] === '+') position++;
          const nextValue = parseUnary();
          value = value && nextValue;
        }
        return value;
      };
      const parseOr = () => {
        let value = parseAnd();
        while (position < tokens.length && (tokens[position].toUpperCase() === 'OR' || tokens[position] === '|')) {
          position++;
          const nextValue = parseAnd();
          value = value || nextValue;
        }
        return value;
      };
      return parseOr();
    };
    const metricMatches = (row, filter) => ({
      functional: row.recordKind === 'functional-element',
      direct: row.documentationTier === 'direct',
      'caller-context': row.documentationTier === 'caller-context',
      'total-documented': ['direct', 'caller-context'].includes(row.documentationTier),
      unresolved: row.refinementStatus === 'parameter-gate-not-found' && row.documentationTier === 'none',
      'header-help': row.recordKind === 'parameter-help' && row.helpDocumented,
      'header-help-missing': row.recordKind === 'parameter-help' && !row.helpDocumented
    })[filter];
    const matches = row => {
      const query = document.getElementById('query').value.trim();
      const selected = Object.entries(state.metricFilters);
      const included = selected.filter(([, mode]) => mode === 'include').map(([filter]) => filter);
      const excluded = selected.filter(([, mode]) => mode === 'exclude').map(([filter]) => filter);
      return evaluateQuery(query, row) &&
        (!included.length || included.some(filter => metricMatches(row, filter))) &&
        !excluded.some(filter => metricMatches(row, filter));
    };
    const render = () => {
      const selected = rows.filter(matches).sort((left, right) => {
        const a = state.sortKey === 'checks' ? checkText(left) : left[state.sortKey];
        const b = state.sortKey === 'checks' ? checkText(right) : right[state.sortKey];
        return String(a).localeCompare(String(b), undefined, { numeric: true }) * state.sortDirection;
      });
      document.getElementById('report-body').innerHTML = selected.map(row => {
        const resultBadge = '<span class="badge ' + (row.refinementStatus === 'parameter-gate-documented' || row.refinementStatus === 'internal-control-flow' ? 'ok' : '') + '">' + esc(row.refinementStatus) + '</span>';
        const checkBadges = resultBadge + checks(row).map(check => '<span class="badge ' + (check.value === 'OK' ? 'ok' : '') + '">C' + check.index + ': ' + esc(check.value) + '</span>').join('');
        const source = esc(row.sourceDisplay + ':' + row.line);
        const element = row.branchKind === 'if' ? 'if (' + row.element + ') {' : row.branchKind === 'elseif' ? 'elseif (' + row.element + ') {' : row.branchKind === 'else' ? 'else {' : row.element;
        const coverage = '<span class="badge ' + (row.documentationTier === 'direct' || row.documentationTier === 'caller-context' ? 'ok' : '') + '">' + esc(row.documentationTier) + '</span>' + (row.reconciliationStatus ? '<span class="badge ok">' + esc(row.reconciliationStatus) + '</span><span class="badge">relevance: ' + esc(row.relevance) + '; confidence: ' + esc(row.confidence) + '/10</span>' : '');
        return '<tr><td>' + esc(row.repository) + '</td><td class="mono source"><a href="' + esc(row.sourceUrl) + '" title="Open ' + esc(row.source) + ' at line ' + esc(row.line) + '">' + source + '</a></td><td class="mono element"><a href="' + esc(row.sourceUrl) + '" title="Open source location">' + esc(element) + '</a></td><td>' + esc(row.type) + '</td><td>' + coverage + '</td><td>' + checkBadges + '</td></tr>';
      }).join('');
      document.getElementById('match-count').textContent = 'Showing ' + selected.length + ' of ' + rows.length + ' functional elements';
    };
    const initTheme = () => {
      const theme = localStorage.getItem('lcm_theme') || 'light';
      document.documentElement.dataset.theme = theme;
      document.getElementById('theme-toggle').textContent = theme === 'light' ? 'Dark Theme' : 'Light Theme';
    };
    document.getElementById('theme-toggle').addEventListener('click', () => {
      const theme = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
      localStorage.setItem('lcm_theme', theme); initTheme();
    });
    document.getElementById('refresh-button').addEventListener('click', () => location.reload());
    document.getElementById('reset-button').addEventListener('click', () => {
      document.getElementById('query').value = '';
      state.metricFilters = {};
      document.querySelectorAll('.metric-button').forEach(button => button.dataset.state = 'ignore');
      render();
    });
    document.getElementById('query').addEventListener('input', render);
    document.querySelectorAll('.metric-button').forEach(button => button.addEventListener('click', () => {
      const filter = button.dataset.filter;
      const stateOrder = filter === 'functional' ? ['ignore', 'include'] : ['ignore', 'include', 'exclude'];
      const nextState = stateOrder[(stateOrder.indexOf(button.dataset.state) + 1) % stateOrder.length];
      button.dataset.state = nextState;
      if (nextState === 'ignore') {
        delete state.metricFilters[filter];
      } else {
        state.metricFilters[filter] = nextState;
      }
      render();
    }));
    document.querySelectorAll('th[data-key]').forEach(header => header.addEventListener('click', () => {
      const key = header.dataset.key;
      state.sortDirection = state.sortKey === key ? state.sortDirection * -1 : 1;
      state.sortKey = key;
      render();
    }));
    initTheme();
    render();
  </script>
</body>
</html>
"@

$outputDirectory = Split-Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}

[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.UTF8Encoding]::new($false))
Write-AnalysisLog -Message "Rendered $($elements.Count) functional elements to $OutputPath." -Level PASS
Write-Host "Rendered LCM Analysis Viewer dashboard: $OutputPath" -ForegroundColor Green

if (-not $NoLaunch) {
  $workspaceRoot = Split-Path $repositoryRoot -Parent
  $dispatcher = Join-Path $workspaceRoot 'LCM_Tools\Invoke-InteractiveDesktop.ps1'
  if (Test-Path -LiteralPath $dispatcher -PathType Leaf) {
    & pwsh -NoProfile -File $dispatcher -FilePath 'explorer.exe' -ArgumentList ('"' + $OutputPath + '"') | Out-Null
  } else {
    Start-Process -FilePath $OutputPath
  }
  Write-AnalysisLog -Message "Launched HTML dashboard: $OutputPath." -Level INFO
}
