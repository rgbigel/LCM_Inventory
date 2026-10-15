<#
.SYNOPSIS
    Launches a governed BCR review from the writable Macrium Reflect baseline.
.DESCRIPTION
    Prepares the F: Macrium image baseline, validates the operator-owned _LCM
    profile, records exact lifecycle review metadata, and opens _LCM.
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
  SessionStartedAt = (Get-Date).ToString('o')
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

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
}
