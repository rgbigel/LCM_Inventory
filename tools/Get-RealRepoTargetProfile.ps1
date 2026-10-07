<#
.SYNOPSIS
  Build a read-only profile of the selected real-repository dry-run target.

.PARAMETER AsJson
  Output the profile in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Output the profile in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Get-RealRepoTargetProfile.ps1 - Profile selected real-repository dry-run target." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Get-RealRepoTargetProfile.ps1 [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -AsJson Output profile as JSON."
  Write-Host "  -Help   (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Get-RealRepoTargetProfile.ps1
Purpose: Build a read-only profile of the selected real-repository dry-run target.
Path: tools/Get-RealRepoTargetProfile.ps1
Authors: LCM_AI Engine
Version: 1.2.0
Caller Contract: Called only after LCM_AI dry-run policy validation; reads target path, git status, and adapter surface presence without writing to the target.
Changelog:
- 2026-08-01: Handled selected repositories without a resolvable HEAD without noisy Git stderr.
- 2026-08-01: Added read-only Git root, branch, and HEAD metadata reporting.
- 2026-08-01: Added read-only real-repository target profile command.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$planPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
$stabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'

Import-Module $qualityGateModulePath -Force

function Invoke-ReadOnlyGit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory=$true)]
    [string[]]$Arguments
  )

  $output = @(& git -C $RepositoryPath @Arguments 2>$null)
  return [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = $output
  }
}

$planValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath
$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
$canObserveTarget = $planValidation.SelectedRepository -and ($planValidation.DryRunEnabled -eq $true -or $planValidation.DryRunStatus -eq 'ready-for-read-only-dry-run')

if (-not $canObserveTarget) {
  $result = [pscustomobject]@{
    Status = 'blocked'
    Reason = $planValidation.DryRunStatus
    RepositoryName = $null
    RepositoryPath = $planValidation.SelectedRepository
    RepositoryRootVerified = $false
    BranchName = $null
    HeadCommit = $null
    GitStatusSummary = 'not-run'
    GitStatusLineCount = 0
    AdapterSurfacePresentCount = 0
    AdapterSurfaceMissingCount = @($plan.dry_run.adapter_surface_candidates).Count
    WriteProbePerformed = $false
  }
} else {
  $selectedRepository = [string]$planValidation.SelectedRepository
  if (-not (Test-Path -LiteralPath (Join-Path $selectedRepository '.git'))) {
    throw "Selected dry-run target is not a Git repository: $selectedRepository"
  }

  $gitStatusResult = Invoke-ReadOnlyGit -RepositoryPath $selectedRepository -Arguments @('status', '--short')
  $gitRootResult = Invoke-ReadOnlyGit -RepositoryPath $selectedRepository -Arguments @('rev-parse', '--show-toplevel')
  $gitBranchResult = Invoke-ReadOnlyGit -RepositoryPath $selectedRepository -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
  $gitHeadResult = Invoke-ReadOnlyGit -RepositoryPath $selectedRepository -Arguments @('rev-parse', 'HEAD')

  if ($gitRootResult.ExitCode -ne 0) {
    throw "Could not read Git repository root for selected dry-run target: $selectedRepository"
  }

  $gitStatusShort = @($gitStatusResult.Output)
  $gitRepositoryRoot = [string]($gitRootResult.Output | Select-Object -First 1)
  $gitBranchName = if ($gitBranchResult.ExitCode -eq 0) { [string]($gitBranchResult.Output | Select-Object -First 1) } else { $null }
  $gitHeadCommit = if ($gitHeadResult.ExitCode -eq 0) { [string]($gitHeadResult.Output | Select-Object -First 1) } else { $null }
  $normalizedSelectedRepository = [System.IO.Path]::GetFullPath($selectedRepository).TrimEnd('\')
  $normalizedGitRepositoryRoot = [System.IO.Path]::GetFullPath($gitRepositoryRoot).TrimEnd('\')
  $adapterSurfaceCandidates = @($plan.dry_run.adapter_surface_candidates)
  $presentSurfaces = @()
  $missingSurfaces = @()

  foreach ($surface in $adapterSurfaceCandidates) {
    $currentSurface = [string]$surface
    $surfacePath = Join-Path $selectedRepository $currentSurface
    if (Test-Path -LiteralPath $surfacePath) {
      $presentSurfaces += $currentSurface
    } else {
      $missingSurfaces += $currentSurface
    }
  }

  $result = [pscustomobject]@{
    Status = 'OK'
    Reason = 'read-only-profile-complete'
    RepositoryName = Split-Path $selectedRepository -Leaf
    RepositoryPath = $selectedRepository
    RepositoryRoot = $gitRepositoryRoot
    RepositoryRootVerified = $normalizedGitRepositoryRoot.Equals($normalizedSelectedRepository, [System.StringComparison]::OrdinalIgnoreCase)
    BranchName = $gitBranchName
    HeadCommit = $gitHeadCommit
    HeadStatus = if ($gitHeadCommit) { 'resolved' } else { 'unresolved' }
    GitStatusSummary = if ($gitStatusShort.Count -eq 0) { 'clean' } else { 'has-changes' }
    GitStatusLineCount = $gitStatusShort.Count
    AdapterSurfacePresentCount = $presentSurfaces.Count
    AdapterSurfaceMissingCount = $missingSurfaces.Count
    AdapterSurfacePresent = $presentSurfaces
    AdapterSurfaceMissing = $missingSurfaces
    WriteProbePerformed = $false
  }
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
} else {
  $result
}