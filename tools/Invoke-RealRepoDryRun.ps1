<#
.SYNOPSIS
  Report LCM_AI real-repository dry-run readiness without writing to any target repository.

.PARAMETER AsJson
  Output dry-run report in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Output dry-run report in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Invoke-RealRepoDryRun.ps1 - Report real-repository dry-run readiness." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Invoke-RealRepoDryRun.ps1 [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -AsJson Output dry-run status as JSON."
  Write-Host "  -Help   (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Invoke-RealRepoDryRun.ps1
Purpose: Report LCM_AI real-repository dry-run readiness without writing to any target repository.
Path: tools/Invoke-RealRepoDryRun.ps1
Authors: LCM_AI Engine
Version: 1.7.0
Caller Contract: Called during readiness and operator preparation; reports blocked/ready state and performs read-only git status only after dry-run is enabled.
Changelog:
- 2026-08-01: Added bottom-up change-request flow summary.
- 2026-08-01: Added phased dry-run sequence summary.
- 2026-08-01: Added intended-action content-state count summary.
- 2026-08-01: Added intended-action preview summary to dry-run report.
- 2026-08-01: Added read-only Git metadata summary from target profile.
- 2026-08-01: Added read-only target profile summary to dry-run report.
- 2026-08-01: Added observation and forbidden-action counts to dry-run report.
- 2026-08-01: Added read-only real-repository dry-run reporter.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$planPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
$stabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'

Import-Module $qualityGateModulePath -Force

$planValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath
$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
$targetProfilePath = Join-Path $PSScriptRoot 'Get-RealRepoTargetProfile.ps1'
$targetProfile = & $targetProfilePath
$actionPlanPath = Join-Path $PSScriptRoot 'Get-RealRepoActionPlan.ps1'
$actionPlan = & $actionPlanPath
$targetMissingCount = @($actionPlan.IntendedActions | Where-Object { $_.ComparisonState -eq 'target-missing' }).Count
$targetDifferentCount = @($actionPlan.IntendedActions | Where-Object { $_.ComparisonState -eq 'target-different' }).Count
$targetIdenticalCount = @($actionPlan.IntendedActions | Where-Object { $_.ComparisonState -eq 'target-identical' }).Count
$statusSummary = 'not-run'
$gitStatusShort = @()
$canObserveTarget = $planValidation.SelectedRepository -and ($planValidation.DryRunEnabled -eq $true -or $planValidation.DryRunStatus -eq 'ready-for-read-only-dry-run')

if ($canObserveTarget) {
  $selectedRepository = [string]$planValidation.SelectedRepository
  if (-not (Test-Path -LiteralPath (Join-Path $selectedRepository '.git'))) {
    throw "Selected dry-run target is not a Git repository: $selectedRepository"
  }

  $gitStatusShort = @(git -C $selectedRepository status --short)
  $statusSummary = if ($gitStatusShort.Count -eq 0) { 'clean' } else { 'has-changes' }
}

$result = [pscustomobject]@{
  Status = 'OK'
  Mode = $planValidation.Mode
  DryRunStatus = $planValidation.DryRunStatus
  SelectedRepository = $planValidation.SelectedRepository
  WriteAllowed = $planValidation.WriteAllowed
  GitStatusSummary = $statusSummary
  GitStatusLineCount = $gitStatusShort.Count
  PlannedObservationCount = @($plan.dry_run.allowed_observations).Count
  ForbiddenActionCount = @($plan.dry_run.forbidden_actions).Count
  TargetProfileStatus = $targetProfile.Status
  RepositoryRootVerified = $targetProfile.RepositoryRootVerified
  BranchName = $targetProfile.BranchName
  HeadCommit = $targetProfile.HeadCommit
  CurrentPhase = $actionPlan.CurrentPhase
  PhaseCount = $actionPlan.PhaseCount
  ChangeRequestOrientation = $actionPlan.ChangeRequestOrientation
  ChangeRequestPhaseCount = $actionPlan.ChangeRequestPhaseCount
  AdapterSurfacePresentCount = $targetProfile.AdapterSurfacePresentCount
  AdapterSurfaceMissingCount = $targetProfile.AdapterSurfaceMissingCount
  ActionPlanStatus = $actionPlan.Status
  IntendedActionCount = $actionPlan.IntendedActionCount
  TargetMissingActionCount = $targetMissingCount
  TargetDifferentActionCount = $targetDifferentCount
  TargetIdenticalActionCount = $targetIdenticalCount
  WriteProbePerformed = $targetProfile.WriteProbePerformed
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  $result
}