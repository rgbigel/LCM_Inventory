[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [ValidatePattern('^COH-\d+$')]
  [string]$CohortId,

  [string]$Notes = '',

  [switch]$IncludeUnreviewed,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: Complete-ReviewCohort.ps1 COH-nnn [-Notes <text>] [-IncludeUnreviewed]' -ForegroundColor Yellow
  return
}
if ([string]::IsNullOrWhiteSpace($CohortId)) {
  throw 'CohortId (COH-nnn) is required.'
}

$workspaceRoot = 'D:\Git_Repositories'
$modulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
Import-Module -Name $modulePath -Force
$plan = Get-LcmReviewCohortCompletionPlan -CohortId $CohortId

foreach ($repositoryPlan in $plan.Repositories) {
  $repoPath = Join-Path $workspaceRoot $repositoryPlan.Repository
  if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
    throw "Cohort repository '$($repositoryPlan.Repository)' is not a Git repository."
  }

  $stagingManifestPath = Join-Path $workspaceRoot "LCM_Inventory\data\reviews\staged_review_$($repositoryPlan.Repository).json"
  if (-not (Test-Path -LiteralPath $stagingManifestPath)) {
    throw "Missing current review staging manifest for '$($repositoryPlan.Repository)'. Relaunch BCR before cohort completion."
  }
  $stagingManifest = Get-Content -LiteralPath $stagingManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $unreviewed = @($stagingManifest.Uncopied)
  if ($unreviewed.Count -gt 0 -and -not $IncludeUnreviewed) {
    Write-Host "Unreviewed live paths in $($repositoryPlan.Repository):" -ForegroundColor Yellow
    $unreviewed | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    if (-not [Environment]::UserInteractive) {
      throw "Repository '$($repositoryPlan.Repository)' has unreviewed paths. Re-run with -IncludeUnreviewed only after explicit review."
    }
    $answer = Read-Host "Include these paths in the cohort commit for $($repositoryPlan.Repository)? [y/N]"
    if ($answer -notmatch '^(?i)y(?:es)?$') {
      throw "Cohort completion cancelled before committing '$($repositoryPlan.Repository)'."
    }
  }

  $members = @($repositoryPlan.Members)
  # Coarse BCR staging refreshes the repository manifest for each member; the final
  # member therefore owns the current exact-identity manifest used by the commit gate.
  $primary = $members[-1]
  & (Join-Path $PSScriptRoot 'Submit-ReviewResult.ps1') -RepositoryPath $repositoryPlan.Repository -CRP $primary.Identity -Result Completed -Notes $Notes
  foreach ($member in @($members | Where-Object { $_.Id -ne $primary.Id })) {
    Move-LcmProposalLifecycleState -Id $member.Id -State completed -Details "Cohort $CohortId review completed with $($primary.Identity)." | Out-Null
  }
  Set-LcmReviewCohort -Action close -CohortId $CohortId | Out-Null
}
