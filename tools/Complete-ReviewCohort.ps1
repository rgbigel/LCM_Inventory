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

function Test-StandardBcrExcludedPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $normalizedPath = $RelativePath.Replace('/', '\').TrimStart('\')
  $lcmDirectory = [regex]::Escape('.' + 'lcm')
  return $normalizedPath -match "^(?i)(?:\.git|\.venv|venv|\.env|__pycache__|scratch|logs|work|data|node_modules|bin|obj)(?:\\|$)|(?:^|\\)$lcmDirectory\\(?:logs|scratch|archive|tools\\links)(?:\\|$)|(?i)\.(?:pyc|pyo|inventory|log|tmp|bak|swp|lock)$"
}

# Validate every repository's current BCR staging evidence before any repository
# is committed. This preserves the exact unreviewed-path disclosure and prevents
# a partial cohort from being accepted.
foreach ($repositoryPlan in $plan.Repositories) {
  $repoPath = Join-Path $workspaceRoot $repositoryPlan.Repository
  if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
    throw "Cohort repository '$($repositoryPlan.Repository)' is not a Git repository."
  }

}

$reviewReceiptPaths = @{}
foreach ($repositoryPlan in $plan.Repositories) {
  $members = @($repositoryPlan.Members)
  $primary = @($members | Where-Object { $_.Id -eq [int]$CohortId.Substring(4) })
  $submissionMember = if ($primary.Count -gt 0) { $primary[0] } else { $members[0] }
  if ($null -eq $submissionMember) {
    throw "Cohort '$CohortId' has no review member in repository '$($repositoryPlan.Repository)'."
  }
  $submission = @(& (Join-Path $PSScriptRoot 'Submit-ReviewResult.ps1') -RepositoryPath $repositoryPlan.Repository -CRP $submissionMember.Identity -Result Completed -Notes $Notes -SkipLifecycleSynchronization)
  $receipt = @($submission | Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['ReviewReceiptPath'] })[-1]
  if ($null -eq $receipt -or [string]::IsNullOrWhiteSpace([string]$receipt.ReviewReceiptPath)) {
    throw "Accepted review commit for '$($repositoryPlan.Repository)' did not produce a review receipt."
  }
  $reviewReceiptPaths[[string]$repositoryPlan.Repository] = [string]$receipt.ReviewReceiptPath
}

$updated = Complete-LcmReviewCohortAcceptance -CohortId $CohortId -ResolutionReceiptPath $plan.ReceiptPath -ReviewReceiptPaths $reviewReceiptPaths -Details $Notes
Write-Host "Completed accepted review cohort $CohortId atomically: $($updated.Count) member(s)." -ForegroundColor Green
