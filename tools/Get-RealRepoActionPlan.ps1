<#
.SYNOPSIS
  Build a read-only intended-action preview for a selected real-repository dry-run target.

.PARAMETER AsJson
  Output the action plan in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Output the action plan in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Get-RealRepoActionPlan.ps1 - Preview real-repository intended adapter actions." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Get-RealRepoActionPlan.ps1 [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -AsJson Output action plan as JSON."
  Write-Host "  -Help   (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Get-RealRepoActionPlan.ps1
Purpose: Build a read-only intended-action preview for a selected real-repository dry-run target.
Path: tools/Get-RealRepoActionPlan.ps1
Authors: LCM_AI Engine
Version: 1.3.0
Caller Contract: Called during real-repository dry-run preparation; reports intended adapter actions without writing to the target repository.
Changelog:
- 2026-08-01: Added bottom-up concrete change-request phase preview.
- 2026-08-01: Added phased documentation-first governance sequence preview.
- 2026-08-01: Added read-only source/target adapter content comparison.
- 2026-08-01: Added read-only real-repository intended-action preview command.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$planPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
$stabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'
$targetProfilePath = Join-Path $PSScriptRoot 'Get-RealRepoTargetProfile.ps1'

Import-Module $qualityGateModulePath -Force

$planValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath
$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
$targetProfile = & $targetProfilePath
$phasePreview = @($plan.action_preview.phases | ForEach-Object {
  $phase = $_
  [pscustomobject]@{
    Id = $phase.id
    Name = $phase.name
    Scope = $phase.scope
    Status = $phase.status
    WriteAllowedNow = $false
  }
})
$changeRequestPhasePreview = @($plan.action_preview.change_request_flow.phases | ForEach-Object {
  $phase = $_
  [pscustomobject]@{
    Id = $phase.id
    Name = $phase.name
    Scope = $phase.scope
    WriteAllowed = $phase.write_allowed
  }
})
$canObserveTarget = $planValidation.SelectedRepository -and ($planValidation.DryRunEnabled -eq $true -or $planValidation.DryRunStatus -eq 'ready-for-read-only-dry-run')

if (-not $canObserveTarget) {
  $result = [pscustomobject]@{
    Status = 'blocked'
    Reason = $planValidation.DryRunStatus
    SelectedRepository = $planValidation.SelectedRepository
    WriteAllowed = $false
    CurrentPhase = 'blocked'
    PhaseCount = $phasePreview.Count
    PhasePreview = $phasePreview
    ChangeRequestOrientation = $plan.action_preview.change_request_flow.orientation
    ChangeRequestPhaseCount = $changeRequestPhasePreview.Count
    ChangeRequestPhasePreview = $changeRequestPhasePreview
    IntendedActionCount = 0
    IntendedActions = @()
    ForbiddenActionTypes = @($plan.action_preview.forbidden_action_types)
  }
} else {
  $intendedActions = @(
    [pscustomobject]@{
      Type = 'would-assess-repository-structure'
      TargetPath = '.'
      Scope = 'workspace-rules'
      ComparisonState = 'not-yet-evaluated'
      WriteAllowedNow = $false
      RequiresFutureApproval = $false
    },
    [pscustomobject]@{
      Type = 'would-check-repository-specifications'
      TargetPath = '.'
      Scope = 'repo-specifications'
      ComparisonState = 'not-yet-evaluated'
      WriteAllowedNow = $false
      RequiresFutureApproval = $false
    },
    [pscustomobject]@{
      Type = 'would-check-documentation-level'
      TargetPath = 'docs/'
      Scope = 'documentation-only'
      ComparisonState = 'not-yet-evaluated'
      WriteAllowedNow = $false
      RequiresFutureApproval = $false
    },
    [pscustomobject]@{
      Type = 'would-report-documentation-discrepancies'
      TargetPath = 'docs/'
      Scope = 'documentation-only'
      ComparisonState = 'pending-documentation-review'
      WriteAllowedNow = $false
      RequiresFutureApproval = $false
    },
    [pscustomobject]@{
      Type = 'would-queue-documentation-change-request'
      TargetPath = 'docs/'
      Scope = 'documentation-only'
      ComparisonState = 'requires-explicit-request'
      WriteAllowedNow = $false
      RequiresFutureApproval = $true
    }
  )

  foreach ($surface in @($plan.dry_run.adapter_surface_candidates)) {
    $currentSurface = [string]$surface
    $sourcePath = Join-Path $workspaceRoot $currentSurface
    $targetPath = Join-Path ([string]$planValidation.SelectedRepository) $currentSurface
    $sourceExists = Test-Path -LiteralPath $sourcePath
    $targetExists = Test-Path -LiteralPath $targetPath
    $sourceHash = $null
    $targetHash = $null

    if ($sourceExists) {
      $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm SHA256).Hash
    }

    if ($targetExists) {
      $targetHash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash
    }

    if (-not $sourceExists) {
      $comparisonState = 'source-missing'
      $actionType = 'would-review-existing-adapter-surface'
    } elseif (-not $targetExists) {
      $comparisonState = 'target-missing'
      $actionType = 'would-create-adapter-surface'
    } elseif ($sourceHash -eq $targetHash) {
      $comparisonState = 'target-identical'
      $actionType = 'would-leave-target-unchanged'
    } else {
      $comparisonState = 'target-different'
      $actionType = 'would-update-adapter-surface'
    }

    $intendedActions += [pscustomobject]@{
      Type = $actionType
      TargetPath = $currentSurface
      SourcePath = $currentSurface
      SourceAuthority = 'LCM_AI'
      SourceExists = $sourceExists
      TargetExists = $targetExists
      ComparisonState = $comparisonState
      SourceSha256 = $sourceHash
      TargetSha256 = $targetHash
      WriteAllowedNow = $false
      RequiresFutureApproval = $true
    }
  }

  $result = [pscustomobject]@{
    Status = 'OK'
    Reason = 'read-only-action-preview-complete'
    SelectedRepository = $planValidation.SelectedRepository
    WriteAllowed = $false
    CurrentPhase = 'phase-01-structure'
    PhaseCount = $phasePreview.Count
    PhasePreview = $phasePreview
    ChangeRequestOrientation = $plan.action_preview.change_request_flow.orientation
    ChangeRequestPhaseCount = $changeRequestPhasePreview.Count
    ChangeRequestPhasePreview = $changeRequestPhasePreview
    IntendedActionCount = $intendedActions.Count
    IntendedActions = $intendedActions
    ForbiddenActionTypes = @($plan.action_preview.forbidden_action_types)
  }
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8
} else {
  $result
}