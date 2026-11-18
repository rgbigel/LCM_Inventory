<#
.SYNOPSIS
    Forwarding shim: completes an accepted review cohort through Complete-Review.ps1 (CRP-357).
.DESCRIPTION
    Module: tools/Complete-ReviewCohort.ps1
    Purpose: Kept for one release so that launchers and habits keep working; the logic lives in Complete-Review.ps1.
    Path: LCM_Inventory/tools/Complete-ReviewCohort.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
    Implementation Choices (CRP-357): forwarding shim; retired with its launchers one release after CRP-357.
#>
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

if ($Help -or [string]::IsNullOrWhiteSpace($CohortId)) {
  Write-Host 'Usage: Complete-ReviewCohort.ps1 COH-nnn [-Notes <text>]  (forwards to Complete-Review.ps1, CRP-357)' -ForegroundColor Yellow
  return
}
Write-Warning 'Complete-ReviewCohort.ps1 is a forwarding shim (CRP-357); use Complete-Review.ps1.'
& (Join-Path $PSScriptRoot 'Complete-Review.ps1') -Target $CohortId -Details $Notes