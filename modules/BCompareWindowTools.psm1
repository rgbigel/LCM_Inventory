<#
.SYNOPSIS
    Selects and closes stale repository-specific Beyond Compare windows.
.DESCRIPTION
    Module: BCompareWindowTools.psm1
    Purpose: Separates same-repository BCompare window selection from process control so
             selection is deterministic and independently testable.
    Path: modules/BCompareWindowTools.psm1
    Authors: Rolf, GitHub Copilot
    Version: 1.0.0
    Date: 2026-09-29
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SameRepositoryBCompareProcess {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]]$Process
  )

  return @($Process | Where-Object {
      $candidate = $_
      $title = [string]$candidate.MainWindowTitle
      $title -like "*$RepositoryName*" -and $title -like '*<-->*'
    })
}

function Remove-StaleBCompareProcess {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false)]
    [object[]]$Process = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue)
  )

  $staleProcess = @(Get-SameRepositoryBCompareProcess -RepositoryName $RepositoryName -Process $Process)
  foreach ($candidate in $staleProcess) {
    if ($PSCmdlet.ShouldProcess([string]$candidate.MainWindowTitle, 'Close stale Beyond Compare review window')) {
      Stop-Process -Id $candidate.Id -Force -ErrorAction SilentlyContinue
    }
  }

  return $staleProcess.Count
}

Export-ModuleMember -Function Get-SameRepositoryBCompareProcess, Remove-StaleBCompareProcess