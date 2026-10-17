[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$RepositoryPath
)

<#
.SYNOPSIS
  Validates the one-use authorization required for a governed Git commit.
.DESCRIPTION
  The pre-commit hook invokes this script. It permits a material commit only
  when Submit-ReviewResult created an authorization for the exact reviewed
  baseline and staged diff.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CommitDiffFingerprint {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $diff = git -C $Path diff --cached --binary
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read the staged Git diff for '$Path'."
  }

  $bytes = [System.Text.Encoding]::UTF8.GetBytes(($diff -join "`n"))
  $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
  return [Convert]::ToHexString($hash).ToLowerInvariant()
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$resolvedRepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$repositoryName = Split-Path $resolvedRepositoryPath -Leaf
$reviewsDirectory = Join-Path $workspaceRoot 'LCM_Inventory\data\reviews'
$authorizationPath = Join-Path $reviewsDirectory "pending_commit_${repositoryName}.json"

if (-not (Test-Path -LiteralPath $authorizationPath)) {
  throw "REVIEW GATE BLOCKED: No current review authorization exists for '$repositoryName'. Run Invoke-MacriumBcrReview.ps1, obtain an accepted disposition, then use Submit-ReviewResult.ps1."
}

try {
  $authorization = Get-Content -LiteralPath $authorizationPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  throw "REVIEW GATE BLOCKED: Review authorization '$authorizationPath' is invalid: $($_.Exception.Message)"
}

if ($authorization.RepositoryName -ne $repositoryName -or $authorization.RepositoryPath -ne $resolvedRepositoryPath) {
  throw "REVIEW GATE BLOCKED: Review authorization does not belong to '$repositoryName'."
}

$currentHead = (git -C $resolvedRepositoryPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $authorization.BaselineCommit -ne $currentHead) {
  throw "REVIEW GATE BLOCKED: The reviewed baseline no longer matches the current HEAD for '$repositoryName'."
}

$expiresAt = [DateTimeOffset]::Parse([string]$authorization.ExpiresAt)
if ($expiresAt -le [DateTimeOffset]::UtcNow) {
  throw "REVIEW GATE BLOCKED: Review authorization for '$repositoryName' expired at $($expiresAt.ToString('u'))."
}

$actualFingerprint = Get-CommitDiffFingerprint -Path $resolvedRepositoryPath
if ($authorization.StagedDiffSha256 -ne $actualFingerprint) {
  throw "REVIEW GATE BLOCKED: The staged diff differs from the approved review selection for '$repositoryName'."
}

exit 0
