<#
.SYNOPSIS
  Create a target-local Docs/Methods method instance for a selected real repository.

.PARAMETER RepositoryPath
  Absolute or relative path to the target repository.

.PARAMETER Force
  Overwrites existing method instance if present.

.PARAMETER Trace
  Enables verbose diagnostic tracing output.

.PARAMETER AsJson
  Output initialization result as JSON.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Absolute or relative path to the target repository.')]
  [string]$RepositoryPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Overwrites existing method instance if present.')]
  [switch]$Force,

  [Parameter(Mandatory = $false, HelpMessage = 'Enables verbose diagnostic tracing output.')]
  [Alias('t')]
  [switch]$Trace,

  [Parameter(Mandatory = $false, HelpMessage = 'Output initialization result as JSON.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Initialize-RealRepoMethodInstance.ps1 - Bootstrap target-local Docs/Methods instance." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Initialize-RealRepoMethodInstance.ps1 [-RepositoryPath <path>] [-Force] [-Trace] [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -RepositoryPath Path to target repository."
  Write-Host "  -Force          Overwrite existing method instance."
  Write-Host "  -Trace (-t)     Verbose diagnostic tracing."
  Write-Host "  -AsJson         Output as JSON."
  Write-Host "  -Help (-h, -?)  Displays this help message."
  exit 0
}

<#
Module: Initialize-RealRepoMethodInstance.ps1
Purpose: Create a target-local Docs/Methods method instance for a selected real repository.
Path: tools/Initialize-RealRepoMethodInstance.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Called only after explicit operator approval; writes method scaffolding inside the target repository and never stages or commits target changes.
Changelog:
- 2026-08-02: Added target-local method instance bootstrap command.
#>

$scriptName = 'Initialize-RealRepoMethodInstance.ps1'
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

function Set-MethodFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$Content,

    [bool]$Overwrite
  )

  if ((Test-Path -LiteralPath $Path) -and -not $Overwrite) {
    return 'existing'
  }

  $Content | Set-Content -Path $Path -Encoding utf8
  return 'written'
}

$planValidation = Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot -RealRepoTestPlanPath $planPath -StabilizationPath $stabilizationPath
$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json

if (-not $RepositoryPath) {
  $RepositoryPath = [string]$planValidation.SelectedRepository
}

if (-not $RepositoryPath) {
  throw 'RepositoryPath was not provided and no selected repository exists in the real-repository test plan.'
}

$targetRepositoryPath = [System.IO.Path]::GetFullPath($RepositoryPath).TrimEnd('\')
$selectedRepositoryPath = if ($planValidation.SelectedRepository) { [System.IO.Path]::GetFullPath([string]$planValidation.SelectedRepository).TrimEnd('\') } else { $null }

Write-TraceMessage -Message "Workspace root: $workspaceRoot" -Enabled $Trace
Write-TraceMessage -Message "Target repository: $targetRepositoryPath" -Enabled $Trace

if ($selectedRepositoryPath -and -not $targetRepositoryPath.Equals($selectedRepositoryPath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Target repository must match selected real-repository candidate: $selectedRepositoryPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $targetRepositoryPath '.git'))) {
  throw "Target repository is not a Git repository: $targetRepositoryPath"
}

$docsRoot = Get-TargetDocsRoot -TargetRepositoryPath $targetRepositoryPath
$methodRoot = Join-Path $docsRoot 'Methods'
$dryRunRoot = Join-Path $methodRoot 'DryRun'
$logRoot = Join-Path $methodRoot 'Logs'
$resultRoot = Join-Path $methodRoot 'Results'
$proposalRoot = Join-Path $methodRoot 'Proposals'
$createdDirectories = @()

foreach ($directoryPath in @($docsRoot, $methodRoot, $dryRunRoot, $logRoot, $resultRoot, $proposalRoot)) {
  if (-not (Test-Path -LiteralPath $directoryPath)) {
    New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    $createdDirectories += $directoryPath
    Write-TraceMessage -Message "Created directory: $directoryPath" -Enabled $Trace
  } else {
    Write-TraceMessage -Message "Directory already exists: $directoryPath" -Enabled $Trace
  }
}

$relativeMethodRoot = [System.IO.Path]::GetRelativePath($targetRepositoryPath, $methodRoot).Replace('\', '/')
$manifestPath = Join-Path $methodRoot 'MethodInstance.json'
$readmePath = Join-Path $methodRoot 'README.md'
$dryRunReadmePath = Join-Path $dryRunRoot 'README.md'
$logReadmePath = Join-Path $logRoot 'README.md'
$resultReadmePath = Join-Path $resultRoot 'README.md'
$proposalReadmePath = Join-Path $proposalRoot 'README.md'
$timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'

$manifest = [ordered]@{
  meta = [ordered]@{
    module = 'MethodInstance.json'
    path = "$relativeMethodRoot/MethodInstance.json"
    version = '1.0.0'
    config_type = 'target-local-method-instance'
    generated_by = $scriptName
    generated_by_version = $scriptVersion
    generated_at = $timestamp
  }
  repository = [ordered]@{
    path = $targetRepositoryPath
    selected_by_workspace_ai = $true
  }
  method_instance = [ordered]@{
    canonical_root = 'Docs/Methods'
    physical_root = $relativeMethodRoot
    dry_run_root = "$relativeMethodRoot/DryRun"
    log_root = "$relativeMethodRoot/Logs"
    result_root = "$relativeMethodRoot/Results"
    proposal_root = "$relativeMethodRoot/Proposals"
    proposal_review_format = 'md'
    structural_override = $true
    auto_accepted_for_candidate_repo = $true
  }
  ownership = [ordered]@{
    target_repo_owns_dry_run_results = $true
    target_repo_owns_work_logs = $true
    target_repo_owns_repo_proposals = $true
    workspace_ai_role = 'method-baseline-only'
  }
  constraints = [ordered]@{
    bootstrap_does_not_stage_or_commit = $true
    bootstrap_does_not_modify_workspace_ai_state = $true
    proposals_directory_is_working_review_queue = $true
    accepted_implemented_proposals_are_void = $true
  }
}

$methodReadme = @"
# Target-Local Method Instance

This directory is the target-local LCM_AI method instance for this repository.

LCM_AI defines the baseline method. This repository owns repo-specific dry-run state, logs, results, proposals, and method application artifacts here.

Canonical method root: Docs/Methods
Physical method root: $relativeMethodRoot

The method instance is an automatically accepted structural override for candidate repositories. It does not grant write permission for unrelated code or documentation changes.
"@

$dryRunReadme = @"
# DryRun

Target-local dry-run state and read-only observation outputs belong here.
"@

$logReadme = @"
# Logs

Target-local method logs belong here. LCM_AI must not store logs for this repository's work.
"@

$resultReadme = @"
# Results

Target-local verification and dry-run results belong here.
"@

$proposalReadme = @"
# Proposals

Target-local Markdown proposals belong here while they are review artifacts.

This directory is a working review queue, not a permanent archive. Once an accepted proposal has led to accepted documentation or code changes, the proposal file is void and should be removed. Durable evidence belongs in logs, results, commit history, and accepted records.
"@

$fileResults = @()
$fileResults += [pscustomobject]@{ Path = $manifestPath; Status = Set-MethodFile -Path $manifestPath -Content ($manifest | ConvertTo-Json -Depth 8) -Overwrite $Force }
$fileResults += [pscustomobject]@{ Path = $readmePath; Status = Set-MethodFile -Path $readmePath -Content $methodReadme -Overwrite $Force }
$fileResults += [pscustomobject]@{ Path = $dryRunReadmePath; Status = Set-MethodFile -Path $dryRunReadmePath -Content $dryRunReadme -Overwrite $Force }
$fileResults += [pscustomobject]@{ Path = $logReadmePath; Status = Set-MethodFile -Path $logReadmePath -Content $logReadme -Overwrite $Force }
$fileResults += [pscustomobject]@{ Path = $resultReadmePath; Status = Set-MethodFile -Path $resultReadmePath -Content $resultReadme -Overwrite $Force }
$fileResults += [pscustomobject]@{ Path = $proposalReadmePath; Status = Set-MethodFile -Path $proposalReadmePath -Content $proposalReadme -Overwrite $Force }

$result = [pscustomobject]@{
  Status = 'OK'
  ScriptName = $scriptName
  ScriptVersion = $scriptVersion
  RepositoryPath = $targetRepositoryPath
  CanonicalMethodRoot = 'Docs/Methods'
  PhysicalMethodRoot = $relativeMethodRoot
  CreatedDirectoryCount = $createdDirectories.Count
  CreatedDirectories = @($createdDirectories | ForEach-Object { [System.IO.Path]::GetRelativePath($targetRepositoryPath, $_).Replace('\', '/') })
  FileResults = @($fileResults | ForEach-Object {
    [pscustomobject]@{
      Path = [System.IO.Path]::GetRelativePath($targetRepositoryPath, $_.Path).Replace('\', '/')
      Status = $_.Status
    }
  })
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