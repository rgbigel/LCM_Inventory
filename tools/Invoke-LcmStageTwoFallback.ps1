<#
.SYNOPSIS
  System-2 fallback adapter invoking existing LCM readiness validation (Stage 2).
.DESCRIPTION
  Module: tools/Invoke-LcmStageTwoFallback.ps1
  Purpose: Executes baseline LCM System-2 validation when the System-1 decider is
           offline, unconfigured, or produces low-confidence results. Guarantees zero
           functional regression by delegating to established quality gates.
  Path: LCM_AI/tools/Invoke-LcmStageTwoFallback.ps1
  Authors: rgbig, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 08:50:00
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to proposal specification markdown file.')]
  [string]$ProposalPath = '',

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Repository path to validate.')]
  [string]$RepositoryPath = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host ' SYSTEM-2 FALLBACK EVALUATION ADAPTER (Invoke-LcmStageTwoFallback)' -ForegroundColor Green
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Executes baseline LCM System-2 validation (Test-RepoReadiness / Test-GeneralReadiness).'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  pwsh LCM_AI/tools/Invoke-LcmStageTwoFallback.ps1 [-ProposalPath <file>] [-RepositoryPath <dir>] [-h]'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

# Derive target repository if not explicitly provided
if ([string]::IsNullOrWhiteSpace($RepositoryPath) -and -not [string]::IsNullOrWhiteSpace($ProposalPath)) {
  if (Test-Path -LiteralPath $ProposalPath) {
    $raw = Get-Content -LiteralPath $ProposalPath -Raw -Encoding UTF8
    if ($raw -match '(?m)^Scope:\s*(.+)$') {
      $scope = $matches[1].Trim()
      $RepositoryPath = Join-Path $workspaceRoot $scope
    }
  }
}

if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
  $RepositoryPath = Join-Path $workspaceRoot 'LCM_AI'
}

$passed = $false
$details = ''
$failureCount = 0

# Check for local Test-RepoReadiness.ps1 or general readiness gate
$localGate = Join-Path $RepositoryPath 'tools\Test-RepoReadiness.ps1'
$generalGate = Join-Path $workspaceRoot 'LCM_Inventory\tools\Test-GeneralReadiness.ps1'

if (Test-Path -LiteralPath $localGate) {
  try {
    $null = & pwsh -NoProfile -File $localGate
    $passed = ($LASTEXITCODE -eq 0)
    $details = "Executed repo readiness gate: $localGate (ExitCode: $LASTEXITCODE)"
  } catch {
    $passed = $false
    $details = "Repo readiness execution failed: $($_.Exception.Message)"
    $failureCount = 1
  }
} elseif (Test-Path -LiteralPath $generalGate) {
  try {
    $null = & pwsh -NoProfile -File $generalGate -RepositoryPath $RepositoryPath
    $passed = ($LASTEXITCODE -eq 0)
    $details = "Executed general quality gates: $generalGate (ExitCode: $LASTEXITCODE)"
  } catch {
    $passed = $false
    $details = "General quality gate execution failed: $($_.Exception.Message)"
    $failureCount = 1
  }
} else {
  $passed = $false
  $details = "No quality gate script found for repository at '$RepositoryPath'."
  $failureCount = 1
}

$decision = if ($passed) { 'Approved' } else { 'Rejected' }

[PSCustomObject]@{
  Passed       = $passed
  Decision     = $decision
  Confidence   = 1.0
  Details      = $details
  FailureCount = $failureCount
  Repository   = $RepositoryPath
  Timestamp    = $timestamp
}

