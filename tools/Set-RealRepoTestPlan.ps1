<#
.SYNOPSIS
  Update the LCM_AI real-repository test plan without enabling writes.

.PARAMETER RepositoryPath
  Path to candidate target repository.

.PARAMETER Mode
  Target test plan mode ('not-selected', 'candidate-selected', 'dry-run').

.PARAMETER ClearSelection
  Clears the current target candidate selection.

.PARAMETER EnableDryRun
  Requests enabling dry-run mode for candidate.

.PARAMETER ConfirmReadOnlyDryRun
  Confirms that dry-run is strictly read-only.

.PARAMETER AsJson
  Output updated test plan in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Path to candidate target repository.')]
  [string]$RepositoryPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Target test plan mode (not-selected, candidate-selected, dry-run).')]
  [ValidateSet('not-selected', 'candidate-selected', 'dry-run')]
  [string]$Mode,

  [Parameter(Mandatory = $false, HelpMessage = 'Clears the current target candidate selection.')]
  [switch]$ClearSelection,

  [Parameter(Mandatory = $false, HelpMessage = 'Requests enabling dry-run mode for candidate.')]
  [switch]$EnableDryRun,

  [Parameter(Mandatory = $false, HelpMessage = 'Confirms that dry-run is strictly read-only.')]
  [switch]$ConfirmReadOnlyDryRun,

  [Parameter(Mandatory = $false, HelpMessage = 'Output updated test plan in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Set-RealRepoTestPlan.ps1 - Update real-repository test plan state." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Set-RealRepoTestPlan.ps1 [-RepositoryPath <path>] [-Mode <mode>] [-ClearSelection] [-EnableDryRun] [-ConfirmReadOnlyDryRun] [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -RepositoryPath         Path to repository."
  Write-Host "  -Mode                   Target mode."
  Write-Host "  -ClearSelection         Clear selection."
  Write-Host "  -EnableDryRun           Request dry-run."
  Write-Host "  -ConfirmReadOnlyDryRun  Confirm read-only execution."
  Write-Host "  -AsJson                 Output as JSON."
  Write-Host "  -Help (-h, -?)          Displays this help message."
  exit 0
}

<#
Module: Set-RealRepoTestPlan.ps1
Purpose: Update the LCM_AI real-repository test plan without enabling writes.
Path: tools/Set-RealRepoTestPlan.ps1
Authors: LCM_AI Engine
Version: 1.3.0
Caller Contract: Called only for LCM_AI governance preparation; refuses write enablement and validates policy after updating the local plan file.
Changelog:
- 2026-08-02: Blocked LCM_AI-local dry-run enablement; target repos must own dry-run state through Docs/Methods.
- 2026-08-01: Synchronized target-profile and action-preview status fields during candidate transitions.
- 2026-08-01: Added candidate Git repository validation and explicit read-only dry-run confirmation.
- 2026-08-01: Added guarded real-repository test plan update command.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$planPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
$stabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'

Import-Module $qualityGateModulePath -Force

if (-not (Test-Path -LiteralPath $planPath)) {
  throw "Real-repository test plan not found: $planPath"
}

if ($RepositoryPath -and $ClearSelection) {
  throw 'Use either -RepositoryPath or -ClearSelection, not both.'
}

$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
$stabilizationState = Get-Content -Raw -Path $stabilizationPath | ConvertFrom-Json

if ($Mode -eq 'dry-run' -and -not $EnableDryRun) {
  throw 'LCM_AI-local dry-run mode is no longer supported; create a target-local Docs/Methods method instance instead.'
}

if ($ClearSelection) {
  $plan.selected_repository = $null
  $plan.mode = 'not-selected'
  $plan.enabled = $false
  $plan.write_allowed = $false
  $plan.confirmation_token = $null
  $plan.dry_run.enabled = $false
  $plan.dry_run.status = 'blocked-until-repository-selected'
  $plan.target_profile.status = 'not-run'
  $plan.target_profile.repository_name = $null
  $plan.target_profile.repository_path = $null
  $plan.target_profile.repository_root_verified = $false
  $plan.target_profile.branch_name = $null
  $plan.target_profile.head_commit = $null
  $plan.target_profile.git_status_summary = 'not-run'
  $plan.target_profile.adapter_surface_present_count = 0
  $plan.target_profile.adapter_surface_missing_count = 0
  $plan.target_profile.write_probe_performed = $false
  $plan.action_preview.status = 'blocked-until-repository-selected'
  $plan.action_preview.action_count = 0
  $plan.action_preview.current_phase = 'blocked'
}

if ($RepositoryPath) {
  $fullRepositoryPath = [System.IO.Path]::GetFullPath($RepositoryPath).TrimEnd('\')
  $workspaceRootPath = [System.IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\')

  if ($fullRepositoryPath.Equals($workspaceRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'LCM_AI cannot be selected as its own real-repository test target.'
  }

  foreach ($offLimitsPath in @($stabilizationState.off_limits_paths)) {
    $normalizedOffLimitsPath = [System.IO.Path]::GetFullPath([string]$offLimitsPath).TrimEnd('\')
    if ($fullRepositoryPath.Equals($normalizedOffLimitsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Selected repository is off-limits: $fullRepositoryPath"
    }
  }

  if (-not (Test-Path -LiteralPath (Join-Path $fullRepositoryPath '.git'))) {
    throw "Selected repository must be an existing Git repository: $fullRepositoryPath"
  }

  $plan.selected_repository = $fullRepositoryPath
  $plan.mode = 'candidate-selected'
  $plan.enabled = $false
  $plan.write_allowed = $false
  $plan.confirmation_token = $null
  $plan.dry_run.enabled = $false
  $plan.dry_run.status = 'blocked-until-target-local-method-instance'
  $plan.target_profile.status = 'not-run'
  $plan.target_profile.repository_name = Split-Path $fullRepositoryPath -Leaf
  $plan.target_profile.repository_path = $fullRepositoryPath
  $plan.target_profile.repository_root_verified = $false
  $plan.target_profile.branch_name = $null
  $plan.target_profile.head_commit = $null
  $plan.target_profile.git_status_summary = 'not-run'
  $plan.target_profile.adapter_surface_present_count = 0
  $plan.target_profile.adapter_surface_missing_count = @($plan.dry_run.adapter_surface_candidates).Count
  $plan.target_profile.write_probe_performed = $false
  $targetMethodInstance = Resolve-TargetMethodInstance -RepositoryPath $fullRepositoryPath
  if ($targetMethodInstance.Exists) {
    $plan.dry_run.status = 'ready-for-read-only-dry-run'
    $plan.action_preview.status = 'ready-read-only-action-preview'
    $plan.action_preview.current_phase = 'phase-01-structure'
  } else {
    $plan.dry_run.status = 'blocked-until-target-local-method-instance'
    $plan.action_preview.status = 'blocked-until-target-local-method-instance'
    $plan.action_preview.current_phase = 'blocked'
  }
  $plan.action_preview.action_count = 0
}

if ($Mode) {
  $plan.mode = $Mode
}

if ($EnableDryRun) {
  throw 'LCM_AI must not enable or store target-repo dry-run state. Establish the target-local Docs/Methods method instance first.'
}

if ($plan.write_allowed -ne $false -or $plan.dry_run.write_allowed -ne $false) {
  throw 'Set-RealRepoTestPlan never enables write permissions.'
}

$json = $plan | ConvertTo-Json -Depth 10
if ($PSCmdlet.ShouldProcess($planPath, 'Update LCM_AI real-repository test plan')) {
  Set-Content -Path $planPath -Value $json -Encoding utf8
}

$result = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  $result
}