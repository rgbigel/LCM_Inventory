<#
.SYNOPSIS
  Detaches the current Macrium BCR baseline from F: through I:.
.DESCRIPTION
  Detaches only local volumes with the expected Macrium volume label and waits
  until each targeted drive letter is unavailable.
  Path: LCM_Inventory/tools/Dismount-MacriumCurrentBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-16
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet('F', 'G', 'H', 'I')]
  [string]$DriveLetter = '',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [ValidateRange(30, 600)]
  [int]$DetachTimeoutSeconds = 120,

  [switch]$ConfirmDetach,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Dismount-MacriumCurrentBaseline.ps1 [-DriveLetter <F|G|H|I>] [-ConfirmDetach] [-h]'
  Write-Host '  Detaches only the expected Macrium BCR baseline. -ConfirmDetach is required.'
  return
}
if (-not $ConfirmDetach -and -not $WhatIfPreference) {
  throw 'Detaching a writable Macrium baseline requires explicit -ConfirmDetach.'
}

$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
}

$letters = if ([string]::IsNullOrWhiteSpace($DriveLetter)) { @('F', 'G', 'H', 'I') } else { @($DriveLetter) }
$detached = [System.Collections.Generic.List[string]]::new()
foreach ($letter in $letters) {
  $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
  if ($null -eq $disk -or $disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
    continue
  }

  if ($WhatIfPreference) {
    Write-Host "WhatIf: would detach ${letter}: with expected label '$ExpectedVolumeLabel'."
    continue
  }

  Write-Verbose "Detaching $letter`: with expected label '$ExpectedVolumeLabel'."
  & $reflectPath $letter '-u'
  $detachExitCode = if (Test-Path variable:global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
  if ($detachExitCode -ne 0) {
    throw "Macrium detach failed for ${letter}: with exit code $detachExitCode."
  }

  $deadline = (Get-Date).AddSeconds($DetachTimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
  } while ($null -ne $disk -and (Get-Date) -lt $deadline)
  if ($null -ne $disk) {
    throw "Macrium did not detach ${letter}: within $DetachTimeoutSeconds seconds."
  }
  $detached.Add("$letter`:")
}

if ($detached.Count -eq 0) {
  if ($WhatIfPreference) {
    return
  }
  throw "No '$ExpectedVolumeLabel' Macrium baseline was mounted in $($letters -join ', ')."
}

[pscustomobject]@{
  DetachedDrives = @($detached)
  ExpectedVolumeLabel = $ExpectedVolumeLabel
  ConfirmedUnavailable = $true
}
