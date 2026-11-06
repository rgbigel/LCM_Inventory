<#
.SYNOPSIS
  Mounts the latest completed same-day Macrium image as the writable BCR baseline.
.DESCRIPTION
  Requires explicit confirmation, then delegates to the canonical Macrium
  baseline workflow. It never starts another backup; absent a completed daily
  image, it fails and reports that fact.
  Path: LCM_Inventory/tools/Mount-MacriumLatestBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-06
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$ConfirmMount,

  [string]$ReviewScope = '',

  [Parameter(Mandatory = $false)]
  [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

  [ValidateRange(30, 600)]
  [int]$MountTimeoutSeconds = 120,

  [switch]$NoLaunchReview,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Mount-MacriumLatestBaseline.ps1 -ConfirmMount [-ReviewScope <CRP|BUG>] [-NoLaunchReview] [-h]'
  Write-Host '  Mounts the latest completed same-day Macrium image. -ConfirmMount is required.'
  return
}
if (-not $ConfirmMount -and -not $WhatIfPreference) {
  throw 'Mounting a writable Macrium baseline requires explicit -ConfirmMount.'
}

$baselineTool = Join-Path $PSScriptRoot 'Invoke-MacriumDailyBcrBaseline.ps1'
if (-not (Test-Path -LiteralPath $baselineTool -PathType Leaf)) {
  throw "Canonical Macrium baseline tool was not found: $baselineTool"
}

& $baselineTool -NewBaseline -CandidateDrives $CandidateDrives -ReviewScope $ReviewScope -MountTimeoutSeconds $MountTimeoutSeconds -NoLaunchReview:$NoLaunchReview -WhatIf:$WhatIfPreference -Confirm:$false
