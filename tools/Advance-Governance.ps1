[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the primary governance log file')]
  [string]$LogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the step-level governance log file')]
  [string]$StepLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the permanent accepted governance log file')]
  [string]$PermanentLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the proposal registry history JSON file')]
  [string]$ProposalLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the proposal validation entries file')]
  [string]$ProposalValidationPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the stabilization policy file')]
  [string]$StabilizationPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom path to the real-repository test plan file')]
  [string]$RealRepoTestPlanPath,

  [Alias('h', '?')]
  [switch]$Help
)

<#
Module: Advance-Governance.ps1
Purpose: Validate native LCM_AI governance readiness and log separation without staging or committing changes.
Path: tools/Advance-Governance.ps1
Authors: LCM_AI Engine
Version: 2.15.2
Date: 2026-09-10
Caller Contract: Called from VS Code tasks or terminal; validates native governance inputs and reports status.
Changelog:
- 2026-09-10: Added -h / -Help CLI parameter per RULE-PS-010.
- 2026-08-17: Scoped ignored-repositories check to root container settings.json.
- 2026-08-02: Added proposal cleanup check reporting.
- 2026-08-02: Added target-local method instance bootstrap reporting.
- 2026-08-02: Added proposal-directory cleanup reporting.
- 2026-08-02: Added target-local method instance ownership reporting.
- 2026-08-02: Added proposal location and Markdown authority reporting.
- 2026-08-02: Added lifecycle and integrity preflight policy reporting.
- 2026-08-01: Added bottom-up change-request flow reporting.
- 2026-08-01: Added phased documentation-first dry-run sequence reporting.
- 2026-08-01: Added real-repository intended-action preview status reporting.
- 2026-08-01: Added real-repository read-only Git command allow-list reporting.
- 2026-08-01: Added real-repository adapter surface candidate count reporting.
- 2026-08-01: Added real-repository dry-run confirmation requirement reporting.
- 2026-08-01: Added real-repository dry-run status reporting.
- 2026-08-01: Consolidated helper quality gates behind WorkspaceQualityGates module.
- 2026-08-01: Added real-repository test plan and stabilization policy validation reporting.
- 2026-08-01: Added LCM_AI stabilization state and sibling repository ignore validation output.
- 2026-08-01: Added proposal disposition summary output.
- 2026-08-01: Grouped generated artifact changes separately from reviewable pending changes.
- 2026-08-01: Added optional accepted/rejected/modified proposal validation fixture check.
- 2026-08-01: Added normalized proposal disposition validation.
- 2026-08-01: Added validation for structured step proposal registry.
- 2026-08-01: Added validation for step-oriented and permanent accepted governance logs.
- 2026-08-01: Added native governance advancement check for Gemini/Continue migration.
#>

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " WORKSPACE_AI ADVANCE GOVERNANCE VALIDATOR (v2.15.2)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Validates native LCM_AI governance readiness, log separation, and"
  Write-Host "  proposal status integrity without staging or committing changes."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Advance-Governance.ps1 [-LogPath <path>] [-StepLogPath <path>] [-Help]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -LogPath                : Path to Workspace.log file."
  Write-Host "  -StepLogPath            : Path to Workspace.step.log file."
  Write-Host "  -PermanentLogPath       : Path to Workspace.accepted.log file."
  Write-Host "  -ProposalLogPath        : Path to Proposals.json ledger."
  Write-Host "  -ProposalValidationPath : Path to Proposals.validation.json."
  Write-Host "  -StabilizationPath      : Path to stabilization artifact."
  Write-Host "  -RealRepoTestPlanPath   : Path to test plan artifact."
  Write-Host "  -h, -Help, -?           : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'
Import-Module $qualityGateModulePath -Force

if (-not $LogPath) {
  $LogPath = Join-Path $copilotRoot 'Logs\Workspace.log'
}

if (-not $StepLogPath) {
  $StepLogPath = Join-Path $copilotRoot 'Logs\Workspace.step.log'
}

if (-not $PermanentLogPath) {
  $PermanentLogPath = Join-Path $copilotRoot 'Logs\Workspace.accepted.log'
}

if (-not $ProposalLogPath) {
  $ProposalLogPath = Join-Path $copilotRoot 'History\Logs\Proposals.json'
}

if (-not $ProposalValidationPath) {
  $ProposalValidationPath = Join-Path $copilotRoot 'History\Logs\Proposals.validation.json'
}

if (-not $StabilizationPath) {
  $StabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
}

if (-not $RealRepoTestPlanPath) {
  $RealRepoTestPlanPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
}

$requiredPaths = @(
  (Join-Path $workspaceRoot 'AGENTS.md'),
  (Join-Path $workspaceRoot '.github\agents\Workspace-Rules.md'),
  (Join-Path $workspaceRoot '.copilot\Rules\RuleAuthority.md'),
  (Join-Path $workspaceRoot '.copilot\Rules\InvariantRules.md'),
  $ProposalLogPath,
  $StabilizationPath,
  $RealRepoTestPlanPath,
  $LogPath,
  $StepLogPath,
  $PermanentLogPath
)

foreach ($requiredPath in $requiredPaths) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required governance artifact missing: $requiredPath"
  }
}

$status = git -C $workspaceRoot status --short
$allowedDispositions = @('pending-review', 'accepted', 'rejected', 'modified')

function ConvertTo-RepoRelativePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceRoot
  )

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $rootPath = [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  if ($fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($rootPath.Length).TrimStart('\').Replace('\', '/')
  }

  return $Path.Replace('\', '/')
}

function Split-GitStatusByArtifact {
  [CmdletBinding()]
  param(
    [string[]]$StatusLines,

    [string[]]$GeneratedArtifactPaths
  )

  $generatedChanges = @()
  $reviewableChanges = @()

  foreach ($statusLine in @($StatusLines)) {
    $currentStatusLine = $statusLine
    if (-not $currentStatusLine) {
      continue
    }

    $relativePath = $currentStatusLine.Substring(3).Trim().Trim('"').Replace('\', '/')
    if ($GeneratedArtifactPaths -contains $relativePath) {
      $generatedChanges += $currentStatusLine
    } else {
      $reviewableChanges += $currentStatusLine
    }
  }

  return [pscustomobject]@{
    Generated = $generatedChanges
    Reviewable = $reviewableChanges
  }
}

function Test-ProposalRegistry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string[]]$AllowedDispositions
  )

  $proposalState = Get-Content -Raw -Path $Path | ConvertFrom-Json
  if (-not $proposalState.PSObject.Properties['proposals'] -or @($proposalState.proposals).Count -eq 0) {
    throw "Proposal registry is empty: $Path"
  }

  foreach ($proposal in @($proposalState.proposals)) {
    $currentProposal = $proposal
    if (-not $currentProposal.PSObject.Properties['disposition']) {
      throw "Proposal is missing disposition: $($currentProposal.id)"
    }

    if ($AllowedDispositions -notcontains $currentProposal.disposition) {
      throw "Proposal has invalid disposition '$($currentProposal.disposition)': $($currentProposal.id)"
    }

    if (($currentProposal.disposition -eq 'rejected' -or $currentProposal.disposition -eq 'modified') -and -not $currentProposal.PSObject.Properties['disposition_reason']) {
      throw "Proposal requires disposition_reason for disposition '$($currentProposal.disposition)': $($currentProposal.id)"
    }
  }

  return [pscustomobject]@{
    Count = @($proposalState.proposals).Count
    Proposals = @($proposalState.proposals)
  }
}

$proposalValidation = Test-ProposalRegistry -Path $ProposalLogPath -AllowedDispositions $allowedDispositions
$proposalCount = $proposalValidation.Count
if (Test-Path -LiteralPath $ProposalValidationPath) {
  $validationProposalValidation = Test-ProposalRegistry -Path $ProposalValidationPath -AllowedDispositions $allowedDispositions
  $validationProposalCount = $validationProposalValidation.Count
}

$stabilizationState = Get-Content -Raw -Path $StabilizationPath | ConvertFrom-Json
$rootContainer = Split-Path $workspaceRoot -Parent
$rootSettings = Join-Path $rootContainer '.vscode\settings.json'
$ignoreValidation = Assert-IgnoredRepositories -SettingsPath $rootSettings -WorkspaceParent $rootContainer
$policyValidation = Assert-StabilizationPolicy -WorkspaceRoot $workspaceRoot -StabilizationPath $StabilizationPath -RealRepoTestPlanPath $RealRepoTestPlanPath
$realRepoPlanValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -StabilizationPath $StabilizationPath -RealRepoTestPlanPath $RealRepoTestPlanPath
$realRepoPlan = Get-Content -Raw -Path $RealRepoTestPlanPath | ConvertFrom-Json

Write-Host 'LCM_AI native governance check: OK'
Write-Host "Stabilization phase: $($stabilizationState.phase)"
Write-Host "Real repository testing enabled: $($stabilizationState.real_repository_testing_enabled)"
Write-Host "Real repository selected: $([bool]$realRepoPlan.selected_repository)"
Write-Host "Real repository dry-run status: $($realRepoPlanValidation.DryRunStatus)"
Write-Host "Real repository dry-run confirmation required: $($realRepoPlanValidation.ConfirmationRequired)"
Write-Host "Real repository adapter surface candidates: $($realRepoPlanValidation.AdapterSurfaceCandidateCount)"
Write-Host "Real repository allowed Git commands: $($realRepoPlanValidation.AllowedGitCommandCount)"
Write-Host "Real repository action preview status: $($realRepoPlanValidation.ActionPreviewStatus)"
Write-Host "Real repository dry-run phases: $($realRepoPlanValidation.ActionPreviewPhaseCount)"
Write-Host "Real repository documentation-first phase: $($realRepoPlanValidation.DocumentationFirstPhase)"
Write-Host "Real repository change-request orientation: $($realRepoPlanValidation.ChangeRequestOrientation)"
Write-Host "Real repository change-request phases: $($realRepoPlanValidation.ChangeRequestPhaseCount)"
Write-Host "Repository lifecycle states: $($realRepoPlanValidation.LifecycleStateCount)"
Write-Host "Integrity preflight mode: $($realRepoPlanValidation.IntegrityPreflightMode)"
Write-Host "Ordinary repo proposal root: $($realRepoPlanValidation.OrdinaryRepoProposalRoot)"
Write-Host "Proposal review format: $($realRepoPlanValidation.ProposalReviewFormat)"
Write-Host "Proposal cleanup required: $($realRepoPlanValidation.ProposalCleanupRequired)"
Write-Host "Void proposal removal required: $($realRepoPlanValidation.VoidProposalRemovalRequired)"
Write-Host "Proposal cleanup check command: $($realRepoPlanValidation.ProposalCleanupCheckCommand)"
Write-Host "Target method root: $($realRepoPlanValidation.TargetMethodRoot)"
Write-Host "Target dry-run root: $($realRepoPlanValidation.TargetDryRunRoot)"
Write-Host "Target bootstrap command: $($realRepoPlanValidation.TargetBootstrapCommand)"
Write-Host "Stabilization policy status: $($policyValidation.Status)"
Write-Host "Sibling repositories ignored: $($ignoreValidation.IgnoredRepositoryCount)"
Write-Host "Governance log: $LogPath"
Write-Host "Step governance log: $StepLogPath"
Write-Host "Permanent accepted log: $PermanentLogPath"
Write-Host "Proposal registry: $ProposalLogPath"
Write-Host "Proposal registry entries: $proposalCount"
if ($validationProposalCount) {
  Write-Host "Proposal validation entries: $validationProposalCount"
}

Write-Host 'Proposal disposition summary:'
foreach ($allowedDisposition in $allowedDispositions) {
  $dispositionCount = @($proposalValidation.Proposals | Where-Object { $_.disposition -eq $allowedDisposition }).Count
  Write-Host "${allowedDisposition}: $dispositionCount"
}

$generatedArtifactPaths = @(
  (ConvertTo-RepoRelativePath -Path $LogPath -WorkspaceRoot $workspaceRoot),
  (ConvertTo-RepoRelativePath -Path $StepLogPath -WorkspaceRoot $workspaceRoot),
  (ConvertTo-RepoRelativePath -Path $PermanentLogPath -WorkspaceRoot $workspaceRoot)
)
$statusGroups = Split-GitStatusByArtifact -StatusLines @($status) -GeneratedArtifactPaths $generatedArtifactPaths

if ($statusGroups.Reviewable) {
  Write-Host 'Pending review changes:'
  $statusGroups.Reviewable | ForEach-Object {
    $statusLine = $_
    Write-Host $statusLine
  }
} else {
  Write-Host 'Pending review changes: none'
}

if ($statusGroups.Generated) {
  Write-Host 'Generated artifact changes:'
  $statusGroups.Generated | ForEach-Object {
    $statusLine = $_
    Write-Host $statusLine
  }
} else {
  Write-Host 'Generated artifact changes: none'
}