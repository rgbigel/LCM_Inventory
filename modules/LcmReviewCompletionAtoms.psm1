<#
.SYNOPSIS
  Shared atoms for review completion (BUG-352; module named for CRP-357).
.DESCRIPTION
  Module: modules/LcmReviewCompletionAtoms.psm1
  Purpose: Single copy of the BCR exclusion rule: paths that are never committed by a review completion
           (generated data, logs, scratch, virtual environments, build output, temporary files).
  Path: LCM_Inventory/modules/LcmReviewCompletionAtoms.psm1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-18
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

Export-ModuleMember -Function 'Test-LcmBcrExcludedPath'
