<#
.SYNOPSIS
  Shared atoms for review completion (BUG-352; module named for CRP-357).
.DESCRIPTION
  Module: modules/LcmReviewCompletionAtoms.psm1
  Purpose: Single copy of the BCR exclusion rule: paths that are never committed by a review completion
           (generated data, logs, scratch, virtual environments, build output, temporary files).
  Path: LCM_Inventory/modules/LcmReviewCompletionAtoms.psm1
  Authors: Rolf, Claude
  Version: 10.7.5
  Date: 2026-11-18
  Implementation Choices (CRP-357): Get-LcmChangedGovernedRepositories (moved from Invoke-ProposalAction.ps1, workspace as
           parameter) lists the governed repositories with committable changes; used by Complete-Review.ps1.
  Implementation Choices (BUG-352): replaces three copies of the same regex (Submit-ReviewResult.ps1,
           Invoke-ProposalAction.ps1, Complete-ReviewCohort.ps1 - the last one was never called).
#>

Set-StrictMode -Version Latest

function Test-LcmBcrExcludedPath {
  <#
  .SYNOPSIS
    Returns true when a repository-relative path is excluded from review commits.
  .PARAMETER RelativePath
    Path relative to the repository root (forward or backward slashes).
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $normalizedPath = $RelativePath.Replace('/', '\').TrimStart('\')
  $lcmDirectory = [regex]::Escape('.' + 'lcm')
  return $normalizedPath -match "^(?i)(?:\.git|\.venv|venv|\.env|__pycache__|scratch|logs|work|data|node_modules|bin|obj)(?:\\|$)|(?:^|\\)$lcmDirectory\\(?:logs|scratch|archive|tools\\links)(?:\\|$)|(?i)\.(?:pyc|pyo|inventory|log|tmp|bak|swp|lock)$"
}

function Get-LcmChangedGovernedRepositories {
  <#
  .SYNOPSIS
    Lists the governed repositories (RULE-LCM-034, root first) that have committable review changes.
  .PARAMETER WorkspaceRoot
    Workspace root (D:\Git_Repositories); the root repository is reported as 'Git_Repositories'.
  .PARAMETER Repositories
    Repository names to scan (default: the governed list).
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [string[]]$Repositories = @('Git_Repositories', 'LCM_AI', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools')
  )

  $changed = [System.Collections.Generic.List[string]]::new()
  foreach ($name in $Repositories) {
    $repoPath = if ('Git_Repositories' -eq $name) { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $name }
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) { continue }
    $paths = @(
      git -C $repoPath diff --name-only
      git -C $repoPath diff --cached --name-only
      git -C $repoPath ls-files --others --exclude-standard
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $committable = @($paths | Where-Object { -not (Test-LcmBcrExcludedPath -RelativePath $_) })
    if ($committable.Count -gt 0) { $changed.Add($name) }
  }
  return @($changed)
}

Export-ModuleMember -Function 'Test-LcmBcrExcludedPath', 'Get-LcmChangedGovernedRepositories'
