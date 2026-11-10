<#
.SYNOPSIS
  Tests the plausibility of the currently mounted Macrium BCR baseline.
.DESCRIPTION
  Scans only F: through I: for the expected Macrium volume label, verifies the
  workspace root, and reports snapshot corroboration without changing mounts.
  Path: LCM_Inventory/tools/Test-MacriumCurrentBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-16
#>
[CmdletBinding()]
param(
  [ValidateSet('F', 'G', 'H', 'I')]
  [string]$DriveLetter = '',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Test-MacriumCurrentBaseline.ps1 [-DriveLetter <F|G|H|I>] [-ExpectedVolumeLabel <string>] [-h]'
  Write-Host '  Read-only plausibility test for the current Macrium BCR baseline.'
  return
}

$letters = if ([string]::IsNullOrWhiteSpace($DriveLetter)) { @('F', 'G', 'H', 'I') } else { @($DriveLetter) }
$candidates = @(
  foreach ($letter in $letters) {
  $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
  if ($null -eq $disk -or $disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
    continue
  }

  $workspacePath = "$letter`:\Git_Repositories"
  $contextPath = Join-Path $workspacePath 'LCM_AI\.agents\ACTIVE_CONTEXT.md'
  $activityPath = Join-Path $workspacePath 'LCM_Inventory\logs\cm_activity.log'
  $savedAt = ''
  if (Test-Path -LiteralPath $contextPath -PathType Leaf) {
    $context = Get-Content -LiteralPath $contextPath -Raw -Encoding utf8
    $savedMatch = [regex]::Match($context, '(?m)^Saved:\s*(.+)$')
    if ($savedMatch.Success) {
      $savedAt = $savedMatch.Groups[1].Value.Trim()
    }
  }

  [pscustomobject]@{
    Plausible = Test-Path -LiteralPath $workspacePath -PathType Container
    MountedDrive = "$letter`:"
    VolumeLabel = $disk.VolumeName
    WorkspacePath = $workspacePath
    SnapshotSavedAt = $savedAt
    GoodNightObserved = (Test-Path -LiteralPath $activityPath -PathType Leaf) -and
      (Select-String -LiteralPath $activityPath -Pattern '\[GOOD_NIGHT\].*SAVE_ALL_AND_GOOD_NIGHT' -Quiet)
  }
}
)

if ($candidates.Count -eq 0) {
  throw "No plausible '$ExpectedVolumeLabel' Macrium baseline was found in $($letters -join ', ')."
}
if ($candidates.Count -gt 1) {
  throw "Multiple plausible '$ExpectedVolumeLabel' Macrium baselines were found: $($candidates.MountedDrive -join ', ')."
}

Write-Verbose "Plausible Macrium baseline found at $($candidates[0].MountedDrive)."
$candidates[0]
