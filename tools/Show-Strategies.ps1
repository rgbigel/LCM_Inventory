<#
.SYNOPSIS
    Renders and launches the LCM Strategy Engine UI.

.DESCRIPTION
    Compiles strategies from data/proposals/strategies.json and proposals.db into
    data/artifacts/ShowStrategies.html and launches it on the interactive desktop.

.PARAMETER NoLaunch
    Suppresses browser launch and only renders the artifact.

.PARAMETER Help
    Displays parameter documentation and usage syntax.

.EXAMPLE
    pwsh -File tools/Show-Strategies.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help -Detailed $PSCommandPath
    return
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$templatePath = Join-Path $repoRoot 'assets\ShowStrategies.html'
$artifactDir = Join-Path $repoRoot 'data\artifacts'
$artifactPath = Join-Path $artifactDir 'ShowStrategies.html'
$stratJsonPath = Join-Path $repoRoot 'data\proposals\strategies.json'
$propJsonPath = Join-Path $repoRoot 'data\proposals\proposals.json'

if (-not (Test-Path -LiteralPath $artifactDir)) {
    New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
}

$stratData = if (Test-Path -LiteralPath $stratJsonPath) {
    Get-Content -LiteralPath $stratJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
} else {
    [PSCustomObject]@{ strategies = @() }
}

$propData = if (Test-Path -LiteralPath $propJsonPath) {
    Get-Content -LiteralPath $propJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
} else {
    [PSCustomObject]@{ proposals = @() }
}

$payloadObj = [PSCustomObject]@{
    strategies = $stratData.strategies
    proposals  = $propData.proposals
}

$payloadJson = $payloadObj | ConvertTo-Json -Depth 10 -Compress
$templateContent = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8

$renderedHtml = $templateContent.Replace(
    '<script id="lcm-strategies-data" type="application/json">{}</script>',
    "<script id=`"lcm-strategies-data`" type=`"application/json`">$payloadJson</script>"
)

[System.IO.File]::WriteAllText($artifactPath, $renderedHtml, [System.Text.UTF8Encoding]::new($false))

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM STRATEGY DASHBOARD COMPILED" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Artifact : $artifactPath" -ForegroundColor Green
Write-Host " Strategies: $($stratData.strategies.Count) registered" -ForegroundColor Gray

if (-not $NoLaunch) {
    Start-Process $artifactPath
}

