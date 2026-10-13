<#
.SYNOPSIS
  Generates CRP-121 forward and reverse LCM dependency evidence.
.DESCRIPTION
  Module: Complete-ToolDocumentation
  Purpose: Produces data-first WIUD forward call evidence and WUD reverse caller
           evidence without generating per-tool Markdown projections.
  Path: tools/Complete-ToolDocumentation.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
#>

[CmdletBinding()]
param(
  [switch]$Pass1,
  [switch]$Pass2,
  [switch]$All,
  [switch]$Force,
  [switch]$VerifyOnly,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptName = 'Complete-ToolDocumentation'
$scriptVersion = '10.0.0'

if ($Help) {
  Write-Host '==========================================================================' 
  Write-Host " $scriptName (v$scriptVersion)"
  Write-Host '==========================================================================' 
  Write-Host 'USAGE:'
  Write-Host '  pwsh tools\Complete-ToolDocumentation.ps1 -Pass1'
  Write-Host '  pwsh tools\Complete-ToolDocumentation.ps1 -Pass2'
  Write-Host '  pwsh tools\Complete-ToolDocumentation.ps1 -All'
  Write-Host '  pwsh tools\Complete-ToolDocumentation.ps1 -VerifyOnly'
  Write-Host ''
  Write-Host 'PASS 1 creates data\dependencies\forward-index.json (WIUD evidence).'
  Write-Host 'PASS 2 creates data\dependencies\reverse-index.json (WUD evidence).'
  return
}

if (-not $Pass1 -and -not $Pass2 -and -not $All -and -not $VerifyOnly) {
  throw 'Specify -Pass1, -Pass2, -All, or -VerifyOnly.'
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $repositoryRoot -Parent
$dataDirectory = Join-Path $repositoryRoot 'data\dependencies'
$logDirectory = Join-Path $repositoryRoot 'data\logs\lcm'
$forwardPath = Join-Path $dataDirectory 'forward-index.json'
$reversePath = Join-Path $dataDirectory 'reverse-index.json'
$modulePath = Join-Path $repositoryRoot 'modules\LcmDependencyIndex.psm1'
$null = New-Item -ItemType Directory -Path $dataDirectory -Force
$null = New-Item -ItemType Directory -Path $logDirectory -Force
Import-Module -Name $modulePath -Force

$logPath = Join-Path $logDirectory "$scriptName-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-DependencyLog {
  param([string]$Message, [ValidateSet('INFO', 'PASS', 'WARN', 'ERROR')][string]$Level = 'INFO')
  Add-Content -LiteralPath $logPath -Value ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message) -Encoding utf8
}

if ($VerifyOnly) {
  if (-not (Test-Path -LiteralPath $forwardPath -PathType Leaf) -or -not (Test-Path -LiteralPath $reversePath -PathType Leaf)) {
    throw 'Dependency evidence is incomplete; run -All first.'
  }
  $null = Get-Content -LiteralPath $forwardPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
  $null = Get-Content -LiteralPath $reversePath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
  Write-DependencyLog -Message 'Validated existing forward and reverse dependency evidence.' -Level PASS
} else {
  $runPass1 = $Pass1 -or $All
  $runPass2 = $Pass2 -or $All
  if ($runPass1) {
    $forward = New-LcmForwardDependencyIndex -WorkspaceRoot $workspaceRoot
    [System.IO.File]::WriteAllText($forwardPath, ($forward | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    Write-DependencyLog -Message "Generated $(@($forward.edges).Count) forward dependency edges." -Level PASS
  }
  if ($runPass2) {
    if (-not (Test-Path -LiteralPath $forwardPath -PathType Leaf)) {
      throw 'Pass 2 requires forward-index.json; run -Pass1 or -All first.'
    }
    $forward = Get-Content -LiteralPath $forwardPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop
    $reverse = New-LcmReverseDependencyIndex -ForwardIndex $forward
    [System.IO.File]::WriteAllText($reversePath, ($reverse | ConvertTo-Json -Depth 16), [System.Text.UTF8Encoding]::new($false))
    Write-DependencyLog -Message "Generated $(@($reverse.reverse_entries).Count) reverse dependency entries." -Level PASS
  }
}

Write-Host "[SUMMARY] Tool: $scriptName"
Write-Host "[SUMMARY] Version: $scriptVersion"
Write-Host '[SUMMARY] Status: COMPLETED'
Write-Host "[SUMMARY] Log: $logPath"
Write-Host "[SUMMARY] Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
