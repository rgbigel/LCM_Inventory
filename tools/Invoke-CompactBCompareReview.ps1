[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepositoryPath,

  [Parameter(Mandatory = $false)]
  [string]$BaseCommit = 'HEAD',

  [Parameter(Mandatory = $true)]
  [string]$InclusionManifest,

  [Parameter(Mandatory = $false)]
  [string]$ScratchRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'scratch\Compact_BC_Review'),

  [switch]$Launch,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
    Prepares an explicit, read-only compact Beyond Compare review.
.DESCRIPTION
    Module: Invoke-CompactBCompareReview.ps1
    Purpose: Projects only manifest-selected files into scratch Baseline and Working roots,
             preserving each repository-relative path and never staging or editing live files.
    Path: tools/Invoke-CompactBCompareReview.ps1
    Authors: Rolf, GitHub Copilot
    Version: 1.0.0
    Date: 2026-09-29
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Get-Help -LiteralPath $PSCommandPath -Detailed
  return
}

$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\CompactBCompareReview.psm1'
Import-Module -Name $modulePath -Force
$reviewTree = New-CompactBCompareReviewTree -RepositoryPath $RepositoryPath -BaseCommit $BaseCommit -InclusionManifest $InclusionManifest -ScratchRoot $ScratchRoot
$reviewTree

if ($Launch) {
  $bcompare = 'D:\Tools\Beyond Compare 5\BCompare.exe'
  if (-not (Test-Path -LiteralPath $bcompare)) {
    throw "Beyond Compare executable not found: $bcompare"
  }
  $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  $dispatcherCandidates = @(
    (Join-Path $workspaceRoot '.lcm\tools\internal\Invoke-InteractiveDesktop.ps1'),
    (Join-Path $workspaceRoot 'tools\Invoke-InteractiveDesktop.ps1')
  )
  $dispatcherPath = @($dispatcherCandidates | Where-Object { Test-Path -LiteralPath $_ })[0]
  $arguments = ('"{0}" "{1}" /ro1 /ro2' -f $reviewTree.BaselinePath, $reviewTree.WorkingPath)
  if ($dispatcherPath) {
    & pwsh -File $dispatcherPath -FilePath $bcompare -ArgumentList $arguments | Out-Null
  }
  else {
    Start-Process -FilePath $bcompare -ArgumentList @($reviewTree.BaselinePath, $reviewTree.WorkingPath, '/ro1', '/ro2')
  }
}