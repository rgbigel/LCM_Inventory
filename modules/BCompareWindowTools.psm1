<#
.SYNOPSIS
    Selects and closes stale repository-specific Beyond Compare windows.
.DESCRIPTION
    Module: BCompareWindowTools.psm1
    Purpose: Separates same-repository BCompare window selection from process control so
             selection is deterministic and independently testable.
    Path: modules/BCompareWindowTools.psm1
    Authors: Rolf, GitHub Copilot
    Version: 10.0.0
    Date: 2026-10-13
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
    [object[]]$Process,

    [Parameter(Mandatory = $false)]
    [string]$CRP = ''
  )

  return @($Process | Where-Object {
      $candidate = $_
      $title = [string]$candidate.MainWindowTitle
      if ([string]::IsNullOrWhiteSpace($title)) { return $false }
      if ($CRP -and ($title -like "*$CRP*" -or $title -like "*$($CRP.Replace('-', '_'))*")) {
        return $true
      }
      return ($title -like "*$RepositoryName*" -and ($title -like '*<-->*' -or $title -like '*Review*' -or $title -like '*Beyond Compare*'))
    })
}

function Remove-StaleBCompareProcess {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false)]
    [object[]]$Process = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue),

    [Parameter(Mandatory = $false)]
    [string]$CRP = ''
  )

  $staleProcess = @(Get-SameRepositoryBCompareProcess -RepositoryName $RepositoryName -Process $Process -CRP $CRP)
  foreach ($candidate in $staleProcess) {
    if ($PSCmdlet.ShouldProcess([string]$candidate.MainWindowTitle, 'Close stale Beyond Compare review window')) {
      Stop-Process -Id $candidate.Id -Force -ErrorAction SilentlyContinue
    }
  }

  return $staleProcess.Count
}

Export-ModuleMember -Function Get-SameRepositoryBCompareProcess, Remove-StaleBCompareProcess