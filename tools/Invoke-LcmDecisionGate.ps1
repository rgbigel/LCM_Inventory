<#
.SYNOPSIS
  Orchestrator façade for the Multi-Stage System-1 Decision Cascade.
.DESCRIPTION
  Module: tools/Invoke-LcmDecisionGate.ps1
  Purpose: Authoritative single entry point coordinating Stage 0 (Deterministic Pre-Gate),
           Stage 1 (System-1 Decider Client), and Stage 2 (System-2 Fallback Adapter).
           Normalizes result contracts, emits structured telemetry, and manages diagnostic routing.
  Path: LCM_AI/tools/Invoke-LcmDecisionGate.ps1
  Authors: rgbig, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 08:50:00
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to proposal specification markdown file.')]
  [string]$ProposalPath = '',

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Target repository path to validate.')]
  [string]$RepositoryPath = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Minimum confidence score required for Stage 1 acceptance.')]
  [double]$ConfidenceThreshold = 0.85,

  [Parameter(Mandatory = $false, HelpMessage = 'Bypass Stage 1 and execute Stage 2 fallback evaluation directly.')]
  [switch]$ForceFallback,

  [Parameter(Mandatory = $false, HelpMessage = 'Invoke Show-LcmFailureDiagnostic.ps1 upon hard governance failure.')]
  [switch]$DiagnosticOnFailure,

  [Parameter(Mandatory = $false, HelpMessage = 'Prompt operator interactively when LEV produces low confidence (< 85%).')]
  [switch]$Interactive,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host ' SYSTEM-1 DECISION CASCADE ORCHESTRATOR (Invoke-LcmDecisionGate)' -ForegroundColor Green
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Coordinating entry point for Stage 0, Stage 1 (LEV), and Stage 2 (Fallback).'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  pwsh LCM_AI/tools/Invoke-LcmDecisionGate.ps1 [-ProposalPath <file>] [-ConfidenceThreshold 0.85] [-ForceFallback] [-h]'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$scriptDir = $PSScriptRoot
$workspaceRoot = 'D:\Git_Repositories'
$timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

# ------------------------------------------------------------------------------
# STAGE 0: Deterministic Pre-Gate Structural Validation
# ------------------------------------------------------------------------------
$stage0Script = Join-Path $scriptDir 'Test-LcmDeterministicGate.ps1'
if (-not (Test-Path -LiteralPath $stage0Script)) {
  throw "Missing Stage 0 script: $stage0Script"
}

Write-Host "[$timestamp] [STAGE 0] Running deterministic pre-gate validation..." -ForegroundColor Cyan
$stage0Result = & $stage0Script -ProposalPath $ProposalPath -RepositoryPath $RepositoryPath

if (-not $stage0Result.Passed) {
  $failReason = "Stage 0 Deterministic Gate FAILED: $($stage0Result.Errors -join '; ')"
  Write-Host "[FAIL] $failReason" -ForegroundColor Red

  if ($DiagnosticOnFailure) {
    $diagScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Show-LcmFailureDiagnostic.ps1'
    if (Test-Path -LiteralPath $diagScript) {
      try {
        & pwsh -NoProfile -File $diagScript -Action do -TargetExpression $(if ($stage0Result.ProposalId) { $stage0Result.ProposalId } else { 'CRP-252' })
      } catch {}
    }
  }

  $exitObj = [PSCustomObject]@{
    Status        = 'FAILED'
    ExecutionPath = 'Stage0_Deterministic'
    Decision      = 'Rejected'
    Confidence    = 1.0
    Reason        = $failReason
    Timestamp     = $timestamp
  }

  $exitObj
  $global:LASTEXITCODE = 1
  [Environment]::ExitCode = 1
  return
}

Write-Host "[OK] Stage 0 Deterministic Gate passed." -ForegroundColor Green

# ------------------------------------------------------------------------------
# STAGE 1: System-1 Decider Client (/v1/systemone)
# ------------------------------------------------------------------------------
$stage1Script = Join-Path $scriptDir 'Invoke-LcmSystemOneClient.ps1'
if (-not (Test-Path -LiteralPath $stage1Script)) {
  throw "Missing Stage 1 script: $stage1Script"
}

$stage1Result = $null
if (-not $ForceFallback) {
  Write-Host "[$timestamp] [STAGE 1] Invoking System-1 Decider Client..." -ForegroundColor Cyan
  $stage1Result = & $stage1Script -ProposalPath $ProposalPath -ConfidenceThreshold $ConfidenceThreshold
} else {
  Write-Host "[$timestamp] [STAGE 1] Bypassed via -ForceFallback flag." -ForegroundColor Yellow
}

# If Stage 1 is Online and has high confidence, accept System-1 decision directly
if ($null -ne $stage1Result -and (-not $stage1Result.RequiresFallback)) {
  $status = if ($stage1Result.Decision -eq 'Approve' -or $stage1Result.Decision -eq 'Approved') { 'PASSED' } else { 'FAILED' }
  Write-Host "[$status] Stage 1 System-1 decision: $($stage1Result.Decision) (Confidence: $($stage1Result.Confidence))" -ForegroundColor $(if ($status -eq 'PASSED') { 'Green' } else { 'Yellow' })

  $exitCode = if ($status -eq 'PASSED') { 0 } else { 1 }
  $outObj = [PSCustomObject]@{
    Status        = $status
    ExecutionPath = 'Stage1_Lev'
    Decision      = $stage1Result.Decision
    Confidence    = $stage1Result.Confidence
    Reason        = $stage1Result.Reason
    Timestamp     = $timestamp
  }

  $outObj
  $global:LASTEXITCODE = $exitCode
  [Environment]::ExitCode = $exitCode
  return
}

# ------------------------------------------------------------------------------
# STAGE 2: Fallback & Escalation Adapter (System-2 Evaluation)
# ------------------------------------------------------------------------------
# Explicitly surface and triage low-confidence (< 85%) results from Stage 1
if ($null -ne $stage1Result -and $stage1Result.Availability -eq 'Online' -and $stage1Result.Confidence -lt $ConfidenceThreshold) {
  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Yellow
  Write-Host " [ATTENTION] LEV SYSTEM-1 TRIAGE: LOW CONFIDENCE ESCALATION (< $([int]($ConfidenceThreshold * 100))%)" -ForegroundColor Magenta
  Write-Host "==========================================================================" -ForegroundColor Yellow
  Write-Host " Proposal ID  : $($stage0Result.ProposalId)"
  Write-Host " LEV Decision : $($stage1Result.Decision)"
  Write-Host " Confidence   : $([math]::Round($stage1Result.Confidence * 100, 1))% (< $([int]($ConfidenceThreshold * 100))%)"
  Write-Host " Reason (NOUL): $($stage1Result.Reason)"
  Write-Host "==========================================================================" -ForegroundColor Yellow

  $operatorDecision = $null
  if ($Interactive) {
    Write-Host "Operator Options: [1] Accept LEV Decision  [2] Operator Override (Pass)  [3] Fallback to System-2 (Default)" -ForegroundColor Cyan
    $choice = Read-Host -Prompt "Select option [1/2/3]"
    if ($choice -eq '1') {
      $operatorDecision = 'AcceptedLevLowConfidence'
    } elseif ($choice -eq '2') {
      $operatorDecision = 'OperatorOverridden'
    }
  }

  if ($operatorDecision -eq 'AcceptedLevLowConfidence') {
    $outStatus = if ($stage1Result.Decision -eq 'Approve' -or $stage1Result.Decision -eq 'Approved') { 'PASSED' } else { 'FAILED' }
    $outCode = if ($outStatus -eq 'PASSED') { 0 } else { 1 }
    $lowObj = [PSCustomObject]@{
      Status        = $outStatus
      ExecutionPath = 'Stage1_Lev_LowConfidence_Accepted'
      Decision      = $stage1Result.Decision
      Confidence    = $stage1Result.Confidence
      Reason        = "Operator accepted low-confidence LEV decision: $($stage1Result.Reason)"
      Timestamp     = $timestamp
    }
    $lowObj
    $global:LASTEXITCODE = $outCode
    [Environment]::ExitCode = $outCode
    return
  } elseif ($operatorDecision -eq 'OperatorOverridden') {
    $overObj = [PSCustomObject]@{
      Status        = 'PASSED'
      ExecutionPath = 'Stage1_Lev_Operator_Overridden'
      Decision      = 'Approved'
      Confidence    = 1.0
      Reason        = "Operator certified and overrode low-confidence LEV triage: $($stage1Result.Reason)"
      Timestamp     = $timestamp
    }
    $overObj
    $global:LASTEXITCODE = 0
    [Environment]::ExitCode = 0
    return
  }
}

$fallbackReason = if ($ForceFallback) {
  'Forced fallback requested.'
} elseif ($null -ne $stage1Result -and $stage1Result.Availability -eq 'Online' -and $stage1Result.Confidence -lt $ConfidenceThreshold) {
  "Low LEV confidence ($([math]::Round($stage1Result.Confidence * 100, 1))% < $([int]($ConfidenceThreshold * 100))%): $($stage1Result.Reason)"
} elseif ($null -ne $stage1Result) {
  $stage1Result.Reason
} else {
  'Stage 1 unavailable.'
}
Write-Host "[$timestamp] [STAGE 2] Escalating to Stage 2 Fallback ($fallbackReason)..." -ForegroundColor Yellow

$stage2Script = Join-Path $scriptDir 'Invoke-LcmStageTwoFallback.ps1'
if (-not (Test-Path -LiteralPath $stage2Script)) {
  throw "Missing Stage 2 script: $stage2Script"
}

$stage2Result = & $stage2Script -ProposalPath $ProposalPath -RepositoryPath $RepositoryPath

$finalStatus = if ($stage2Result.Passed) { 'PASSED' } else { 'FAILED' }
Write-Host "[$finalStatus] Stage 2 Fallback completed: $($stage2Result.Decision)" -ForegroundColor $(if ($finalStatus -eq 'PASSED') { 'Green' } else { 'Red' })

$finalExitCode = if ($finalStatus -eq 'PASSED') { 0 } else { 1 }

$finalObj = [PSCustomObject]@{
  Status        = $finalStatus
  ExecutionPath = 'Stage2_Fallback'
  Decision      = $stage2Result.Decision
  Confidence    = $stage2Result.Confidence
  Reason        = "Fallback executed ($fallbackReason). Result: $($stage2Result.Details)"
  Timestamp     = $timestamp
}

$finalObj
$global:LASTEXITCODE = $finalExitCode
[Environment]::ExitCode = $finalExitCode
