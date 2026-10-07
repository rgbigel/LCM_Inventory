<#
.SYNOPSIS
  Report target-local proposal files that are void because they are accepted and implemented.

.PARAMETER RepositoryPath
  Path to target repository to scan for cleanup candidates.

.PARAMETER Trace
  Enables verbose diagnostic tracing output.

.PARAMETER AsJson
  Output cleanup scan report in JSON format.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Path to target repository to scan for cleanup candidates.')]
  [string]$RepositoryPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Enables verbose diagnostic tracing output.')]
  [Alias('t')]
  [switch]$Trace,

  [Parameter(Mandatory = $false, HelpMessage = 'Output cleanup scan report in JSON format.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Test-RealRepoProposalCleanup.ps1 - Scan target-local proposal files for cleanup candidates." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Test-RealRepoProposalCleanup.ps1 [-RepositoryPath <path>] [-Trace] [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -RepositoryPath Path to repository."
  Write-Host "  -Trace (-t)     Verbose tracing."
  Write-Host "  -AsJson         Output as JSON."
  Write-Host "  -Help (-h, -?)  Displays this help message."
  exit 0
}

<#
Module: Test-RealRepoProposalCleanup.ps1
Purpose: Report target-local proposal files that are void because they are accepted and implemented.
Path: tools/Test-RealRepoProposalCleanup.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Performs a read-only scan of the selected target repository's method proposal queue; does not delete, stage, or commit files.
Changelog:
- 2026-08-02: Added target-local proposal cleanup candidate scanner.
#>

$scriptName = 'Test-RealRepoProposalCleanup.ps1'
$scriptVersion = '1.0.0'
Write-Host "$scriptName version $scriptVersion"

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'
$planPath = Join-Path $copilotRoot 'History\Logs\RealRepoTestPlan.json'
$stabilizationPath = Join-Path $copilotRoot 'History\Logs\Stabilization.json'
$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'

Import-Module $qualityGateModulePath -Force

function Write-TraceMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [bool]$Enabled
  )

  if ($Enabled) {
    Write-Host "TRACE: $Message"
  }
}

function Get-TargetDocsRoot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$TargetRepositoryPath
  )

  $existingDocsRoot = Get-ChildItem -LiteralPath $TargetRepositoryPath -Directory -ErrorAction Stop | Where-Object { $_.Name -ieq 'Docs' } | Select-Object -First 1
  if ($existingDocsRoot) {
    return $existingDocsRoot.FullName
  }

  return Join-Path $TargetRepositoryPath 'Docs'
}

function Test-ProposalIsAcceptedAndImplemented {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Content
  )

  $hasAcceptedDisposition = $Content -match '(?im)^\s*disposition\s*:\s*accepted\s*$'
  $hasImplementedStatus = $Content -match '(?im)^\s*(implementation_status|implementation-status|implemented)\s*:\s*(implemented|accepted|true)\s*$'
  return ($hasAcceptedDisposition -and $hasImplementedStatus)
}

$planValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath

if (-not $RepositoryPath) {
  $RepositoryPath = [string]$planValidation.SelectedRepository
}

if (-not $RepositoryPath) {
  throw 'RepositoryPath was not provided and no selected repository exists in the real-repository test plan.'
}

$targetRepositoryPath = [System.IO.Path]::GetFullPath($RepositoryPath).TrimEnd('\')
$selectedRepositoryPath = if ($planValidation.SelectedRepository) { [System.IO.Path]::GetFullPath([string]$planValidation.SelectedRepository).TrimEnd('\') } else { $null }

Write-TraceMessage -Message "Target repository: $targetRepositoryPath" -Enabled $Trace

if ($selectedRepositoryPath -and -not $targetRepositoryPath.Equals($selectedRepositoryPath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Target repository must match selected real-repository candidate: $selectedRepositoryPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $targetRepositoryPath '.git'))) {
  throw "Target repository is not a Git repository: $targetRepositoryPath"
}

$docsRoot = Get-TargetDocsRoot -TargetRepositoryPath $targetRepositoryPath
$manifestPath = Join-Path $docsRoot 'Methods\MethodInstance.json'
$proposalRoot = Join-Path $docsRoot 'Methods\Proposals'

if (Test-Path -LiteralPath $manifestPath) {
  $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
  $proposalRoot = Join-Path $targetRepositoryPath ([string]$manifest.method_instance.proposal_root).Replace('/', '\')
}

$proposalFiles = @()
if (Test-Path -LiteralPath $proposalRoot) {
  $proposalFiles = @(Get-ChildItem -LiteralPath $proposalRoot -Recurse -File -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' })
}

$cleanupCandidates = @()
foreach ($proposalFile in $proposalFiles) {
  $currentProposalFile = $proposalFile
  $content = Get-Content -Raw -Path $currentProposalFile.FullName
  if (Test-ProposalIsAcceptedAndImplemented -Content $content) {
    $cleanupCandidates += [pscustomobject]@{
      Path = [System.IO.Path]::GetRelativePath($targetRepositoryPath, $currentProposalFile.FullName).Replace('\', '/')
      Reason = 'accepted-and-implemented-proposal-is-void'
      Action = 'remove-from-proposal-directory-after-accept'
    }
  }
}

$result = [pscustomobject]@{
  Status = 'OK'
  ScriptName = $scriptName
  ScriptVersion = $scriptVersion
  RepositoryPath = $targetRepositoryPath
  ProposalRoot = [System.IO.Path]::GetRelativePath($targetRepositoryPath, $proposalRoot).Replace('\', '/')
  ScannedProposalCount = $proposalFiles.Count
  CleanupCandidateCount = $cleanupCandidates.Count
  CleanupCandidates = $cleanupCandidates
  DeletePerformed = $false
  StagedOrCommitted = $false
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8
} else {
  $result
}

Write-Host 'FINAL STATUS'
Write-Host "Name: $scriptName"
Write-Host "Version: $scriptVersion"
Write-Host 'State: SUCCESS'