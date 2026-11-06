<#
.SYNOPSIS
  Builds a daemon-served failure-analysis snapshot page.
.NOTES
  Module: FailureAnalysisHtml
  Purpose: Builds the retained failure-analysis HTML shell for daemon delivery.
  Path: LCM_Inventory/modules/FailureAnalysisHtml.psm1
  Authors: Rolf, Copilot
  Version: 10.0.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'LcmDisplayVersion.psm1') -Force

function New-FailureAnalysisIndexHtml {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$SnapshotId,
    [switch]$HasJson,
    [switch]$HasMarkdown
  )
  $provenance = Get-LcmDisplayProvenance -ScriptPath (Join-Path $PSScriptRoot '..\tools\Show-FailureAnalysis.ps1') -TemplatePath $PSCommandPath
  $jsonValue = $HasJson.IsPresent.ToString().ToLowerInvariant()
  $jsonLink = if ($HasJson) {
    "<a href=`"http://127.0.0.1:9876/failure-analysis/$SnapshotId/report.json`">Complete JSON evidence</a>"
  } else { '' }
  $markdownLink = if ($HasMarkdown) {
    "<a href=`"http://127.0.0.1:9876/failure-analysis/$SnapshotId/report.md`">Retained Markdown</a>"
  } else { '' }
  @"
<!doctype html>
<html lang="en" data-snapshot-id="$SnapshotId" data-has-json="$jsonValue">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>Failure analysis snapshot $($provenance.Label)</title>
  <link rel="stylesheet" href="http://127.0.0.1:9876/assets/failure-analysis.css">
  <script defer src="http://127.0.0.1:9876/assets/failure-analysis.js"></script>
</head>
<body>
  <header class="topbar">
    <div>
      <p class="eyebrow">LCM INVENTORY / RETAINED EVIDENCE</p>
      <h1>Failure analysis</h1>
      <p class="snapshot">$($provenance.Label)</p>
      <p id="producer-header" class="producer">Producer not recorded</p>
      <p class="snapshot">Snapshot <code>$SnapshotId</code></p>
    </div>
    <nav aria-label="Evidence files">
      $jsonLink
      $markdownLink
    </nav>
  </header>
  <main>
    <section class="overview" aria-labelledby="overview-title">
      <h2 id="overview-title">Summary</h2>
      <p id="load-status" role="status" aria-live="polite">Loading retained evidence…</p>
      <div id="summary" class="summary-grid"></div>
    </section>
    <section aria-labelledby="flow-title">
      <h2 id="flow-title">Execution flow</h2>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Tool</th><th>Outcome</th><th>Source</th><th>Details</th></tr></thead>
          <tbody id="flow-rows"></tbody>
        </table>
      </div>
    </section>
    <section aria-labelledby="source-title">
      <h2 id="source-title">Retained source events</h2>
      <div id="source-events"></div>
    </section>
    <section aria-labelledby="findings-title">
      <h2 id="findings-title">Findings</h2>
      <div id="findings"></div>
    </section>
    <section aria-labelledby="limits-title">
      <h2 id="limits-title">Evidence boundaries and limitations</h2>
      <ul id="limitations"></ul>
    </section>
  </main>
</body>
</html>
"@
}

function Write-FailureAnalysisIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$SnapshotId,
    [switch]$HasJson,
    [switch]$HasMarkdown
  )
  $html = New-FailureAnalysisIndexHtml -SnapshotId $SnapshotId -HasJson:$HasJson -HasMarkdown:$HasMarkdown
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($html -replace '\r?\n', "`r`n"))
  $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
  try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
  return $Path
}

Export-ModuleMember -Function New-FailureAnalysisIndexHtml, Write-FailureAnalysisIndex
