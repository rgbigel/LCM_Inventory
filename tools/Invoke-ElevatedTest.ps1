<#
.SYNOPSIS
Runs Pester test suites with automatic Administrator elevation handoff and structured JSON evidence generation.

.DESCRIPTION
Runs Pester test suites with automatic Administrator elevation handoff and structured JSON evidence generation.

.PARAMETER TestPath
Path to the test directory or test file to execute.

.PARAMETER OutEvidencePath
Target path for the structured JSON test evidence output.

.PARAMETER ForceInProcess
Runs tests in-process even if elevated privileges are requested.

.COMPONENT
LCM_Inventory

.VERSION
1.0.1

.DATE
2026-11-11
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Path to the test directory or test file to execute.")]
  [string]$TestPath = (Join-Path $PSScriptRoot '..\tests'),
    
  [Parameter(Mandatory = $false, HelpMessage = "Target path for the structured JSON test evidence output.")]
  [string]$OutEvidencePath = (Join-Path $PSScriptRoot '..\out\test_results.json'),
    
  [Parameter(Mandatory = $false, HelpMessage = "Runs tests in-process even if elevated privileges are requested.")]
  [switch]$ForceInProcess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ElevationRequired {
  param([string]$TargetRepoRoot)

  # Check LCM_Inventory database cache
  $workspaceRoot = Split-Path $TargetRepoRoot -Parent
  $invPath = Join-Path $workspaceRoot 'LCM_Inventory\data\inventory.json'
  if (Test-Path $invPath) {
    try {
      $inv = Get-Content -Path $invPath -Raw | ConvertFrom-Json
      $repoName = Split-Path $TargetRepoRoot -Leaf
      $repoRecord = $inv.repositories | Where-Object { $_.RepositoryName -eq $repoName } | Select-Object -First 1
      if ($repoRecord -and ($null -ne $repoRecord.ElevationRequired)) {
        return [bool]$repoRecord.ElevationRequired
      }
    }
    catch { }
  }

  return $false
}

$isAdmin = Test-IsAdmin
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$needsElevation = Test-ElevationRequired -TargetRepoRoot $repoRoot

$outDir = Split-Path $OutEvidencePath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if ($isAdmin -or (-not $needsElevation) -or $ForceInProcess) {
  # Elevated / In-Process Execution Mode
  Write-Host "=================================================================" -ForegroundColor Cyan
  Write-Host " Running Test Suite (Context: $(if ($isAdmin) { 'Elevated (Administrator)' } else { 'Standard User' }))" -ForegroundColor Cyan
  Write-Host " Repository Root: $repoRoot" -ForegroundColor Cyan
  Write-Host " Test Path      : $TestPath" -ForegroundColor Cyan
  Write-Host "=================================================================" -ForegroundColor Cyan

  # Ensure modern Pester (v5+) is loaded
  $pesterModule = Get-Module Pester
  if (-not $pesterModule -or $pesterModule.Version.Major -lt 5) {
    $userPester = Join-Path $home "Documents\PowerShell\Modules\Pester\6.1.0\Pester.psd1"
    if (Test-Path -LiteralPath $userPester) {
      Import-Module $userPester -Force
    }
    else {
      Import-Module Pester -MinimumVersion 5.0.0 -Force -ErrorAction SilentlyContinue
    }
  }

  $pesterResults = Invoke-Pester -Path $TestPath -PassThru

  $passed = ($pesterResults.FailedCount -eq 0)
  $failedContainers = @()
  if ($pesterResults.PSObject.Properties['FailedContainers']) {
    $failedContainers = @($pesterResults.FailedContainers | ForEach-Object { $_.Name })
  }

  $duration = 0
  if ($pesterResults.PSObject.Properties['Time'] -and $pesterResults.Time) {
    $duration = [int]($pesterResults.Time.TotalMilliseconds)
  }

  $evidence = [ordered]@{
    '$schema'         = 'https://json-schema.org/draft/2020-12/schema'
    title             = 'Repository Test Execution Evidence'
    timestamp         = (Get-Date).ToString('o')
    repository_root   = $repoRoot
    elevation_context = if ($isAdmin) { 'Administrator' } else { 'User' }
    total_count       = $pesterResults.TotalCount
    passed_count      = $pesterResults.PassedCount
    failed_count      = $pesterResults.FailedCount
    skipped_count     = $pesterResults.SkippedCount
    duration_ms       = $duration
    passed            = $passed
    failed_containers = $failedContainers
  }

  $evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $OutEvidencePath -Encoding UTF8
  Write-Host "`nTest evidence recorded: $OutEvidencePath" -ForegroundColor Green
    
  if (-not $passed) {
    throw "Pester test suite failed with $($pesterResults.FailedCount) failure(s)."
  }
}
else {
  # Non-Elevated IDE / Runner Mode: Launch Elevated Process
  Write-Host "=================================================================" -ForegroundColor Yellow
  Write-Host " Elevation Required: Launching Elevated Test Runner             " -ForegroundColor Yellow
  Write-Host " Target Repository : $repoRoot" -ForegroundColor Yellow
  Write-Host " Evidence Path     : $OutEvidencePath" -ForegroundColor Yellow
  Write-Host "=================================================================" -ForegroundColor Yellow

  # Clear previous evidence file to ensure fresh results
  if (Test-Path $OutEvidencePath) {
    Remove-Item -Path $OutEvidencePath -Force
  }

  $scriptPath = $PSCommandPath
  $argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$scriptPath`"",
    "-TestPath", "`"$TestPath`"",
    "-OutEvidencePath", "`"$OutEvidencePath`""
  )

  Write-Host "Dispatching elevated runner via Start-Process -Verb RunAs..." -ForegroundColor Cyan
  $process = Start-Process -FilePath "pwsh.exe" -ArgumentList $argList -Verb RunAs -PassThru -Wait

  Write-Host "Elevated process finished (ExitCode: $($process.ExitCode))." -ForegroundColor Cyan

  # Read back generated JSON evidence
  if (Test-Path $OutEvidencePath) {
    $evidenceData = Get-Content -Path $OutEvidencePath -Raw | ConvertFrom-Json
    Write-Host "`n=== Elevated Test Execution Summary ===" -ForegroundColor Green
    Write-Host "  Context      : $($evidenceData.elevation_context)" -ForegroundColor Green
    Write-Host "  Total Tests  : $($evidenceData.total_count)" -ForegroundColor Green
    Write-Host "  Passed Tests : $($evidenceData.passed_count)" -ForegroundColor Green
    Write-Host "  Failed Tests : $($evidenceData.failed_count)" -ForegroundColor $(if ($evidenceData.failed_count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Duration     : $($evidenceData.duration_ms) ms" -ForegroundColor Green
    Write-Host "  Passed Gate  : $($evidenceData.passed)" -ForegroundColor $(if ($evidenceData.passed) { 'Green' } else { 'Red' })
        
    if (-not $evidenceData.passed) {
      throw "Elevated test suite reported $($evidenceData.failed_count) failure(s)."
    }
  }
  else {
    throw "Elevated test execution did not produce expected evidence at: $OutEvidencePath"
  }
}
