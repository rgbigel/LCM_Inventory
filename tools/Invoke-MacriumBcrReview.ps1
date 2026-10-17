<#
.SYNOPSIS
    Launches a governed BCR review from the writable Macrium Reflect baseline.
.DESCRIPTION
    Prepares the F: Macrium image baseline, validates the operator-owned _LCM
    profile, records exact lifecycle review metadata, and opens _LCM.

    Module: Invoke-MacriumBcrReview
    Purpose: Opens or reuses the governed Macrium BCR window and records the exact lifecycle review state.
    Path: LCM_Inventory/tools/Invoke-MacriumBcrReview.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.1
    Date: 2026-10-17
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^(CRP|BUG)-\d+$')]
  [string]$CRP,

  [Parameter(Mandatory = $false)]
  [string]$RepositoryName = 'LCM_Inventory',

  [Parameter(Mandatory = $false)]
  [string]$BaseCommit = 'HEAD',

  [Parameter(Mandatory = $false)]
  [switch]$NoLaunch,

  [Parameter(Mandatory = $false)]
  [switch]$LifecycleManaged,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Invoke-MacriumBcrReview.ps1 -CRP <CRP|BUG> [-RepositoryName <repo>] [-BaseCommit <commit>] [-NoLaunch]'
  Write-Host 'Prepares the writable F: Macrium baseline and opens only the _LCM BCR profile.'
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$inventoryRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$proposalManagerPath = Join-Path $inventoryRoot 'modules\ProposalManager.psm1'
Import-Module -Name $proposalManagerPath -Force

$store = Get-ProposalStore
$proposal = @($store.proposals | Where-Object {
  ($_.PSObject.Properties['crp_id'] -and [string]$_.crp_id -eq $CRP) -or
  ($_.PSObject.Properties['cr_id'] -and [string]$_.cr_id -eq $CRP) -or
  ("CRP-$($_.id)" -eq $CRP)
}) | Select-Object -First 1
if ($null -eq $proposal) {
  throw "No lifecycle proposal matches '$CRP'."
}
if (-not $LifecycleManaged -and [string]$proposal.state -notin @('verified', 'in_review')) {
  throw "Direct BCR review for $CRP requires lifecycle state 'verified' or 'in_review'; found '$($proposal.state)'."
}

$repositoryPath = Join-Path $workspaceRoot $RepositoryName
if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath '.git'))) {
  throw "Repository '$RepositoryName' is not available for BCR review."
}

$commit = (git -C $repositoryPath rev-parse --verify $BaseCommit 2>$null).Trim()
if ([string]::IsNullOrWhiteSpace($commit)) {
  throw "Base commit '$BaseCommit' cannot be resolved in '$RepositoryName'."
}

$baselineTool = Join-Path $PSScriptRoot 'Invoke-MacriumDailyBcrBaseline.ps1'
$baselineArgs = @{
  ReviewScope = $CRP
  Confirm = $false
  ReuseMountedBaseline = $true
}
if ($NoLaunch) {
  $baselineArgs.NoLaunchReview = $true
}
$baseline = & $baselineTool @baselineArgs

$lcmAiPath = Join-Path $workspaceRoot 'LCM_AI'
if ((Test-Path -LiteralPath (Join-Path $lcmAiPath '.git')) -and
    -not $RepositoryName.Equals('LCM_AI', [System.StringComparison]::OrdinalIgnoreCase)) {
  $changedPaths = @(git -C $lcmAiPath status --porcelain 2>$null | ForEach-Object {
    if ($_.Length -gt 3) { $_.Substring(3).Trim() }
  } | Where-Object { $_ -and $_ -notmatch '^(scratch|logs|work|data)(\\|/|$)' })
  if ($changedPaths.Count -gt 0) {
    Register-LcmCrossRepositoryReviewObligation -Id $proposal.id -Repository 'LCM_AI' `
      -Reason "Durable LCM_AI changes discovered during $CRP Macrium BCR preparation: $($changedPaths -join ', ')." | Out-Null
  }
}

$metadataDirectory = Join-Path $inventoryRoot "scratch\BC_Review\$CRP"
if (-not (Test-Path -LiteralPath $metadataDirectory)) {
  New-Item -ItemType Directory -Path $metadataDirectory -Force | Out-Null
}
$metadataPath = Join-Path $metadataDirectory '.lcm_review.json'
$existingMetadata = if (Test-Path -LiteralPath $metadataPath) {
  Get-Content -LiteralPath $metadataPath -Raw -Encoding utf8 | ConvertFrom-Json
} else {
  $null
}
$baselineImage = if (-not [string]::IsNullOrWhiteSpace([string]$baseline.ImagePath)) {
  [string]$baseline.ImagePath
} elseif ($null -ne $existingMetadata -and $existingMetadata.PSObject.Properties['BaselineImage']) {
  [string]$existingMetadata.BaselineImage
} else {
  ''
}
[ordered]@{
  RepositoryName = $RepositoryName
  RepositoryPath = $repositoryPath
  BaseCommit = $commit
  BaselineKind = 'MacriumReflect'
  BaselineImage = $baselineImage
  MountedDrive = $baseline.MountedDrive
  Profile = '_LCM'
  ReviewIdentity = $CRP
  ReviewType = 'Lifecycle'
  CRP = $CRP
  ReusedExistingReviewWindow = $baseline.ReusedExistingReviewWindow -eq $true
  SessionStartedAt = (Get-Date).ToString('o')
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

if (-not $LifecycleManaged -and -not $NoLaunch -and [string]$proposal.state -eq 'verified') {
  $store = Get-ProposalStore
  $reviewedProposal = Move-LcmProposalLifecycleState -Id $proposal.id -State 'in_review' `
    -Details "Macrium BCR review reused for $CRP." -Store $store -SkipPersist
  $reviewedProposal | Add-Member -NotePropertyName 'bcr_initiated_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
  $reviewedProposal | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue $null -Force
  $reviewedProposal | Add-Member -NotePropertyName 'bcr_scope' -NotePropertyValue $CRP -Force
  Set-ProposalStore -Store $store
}

[PSCustomObject]@{
  CRP = $CRP
  RepositoryName = $RepositoryName
  BaseCommit = $commit
  BaselineKind = 'MacriumReflect'
  BaselineImage = $baselineImage
  MountedDrive = $baseline.MountedDrive
  Profile = '_LCM'
  ReviewMetadataPath = $metadataPath
  Launched = $baseline.Launched
  ReusedExistingReviewWindow = $baseline.ReusedExistingReviewWindow -eq $true
}
