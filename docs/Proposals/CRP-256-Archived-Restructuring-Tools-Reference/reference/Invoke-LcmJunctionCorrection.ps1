<#
.SYNOPSIS
  Creates or replaces one approved LCM migration junction.
.DESCRIPTION
  Refuses to delete a physical directory. The existing path may be absent or
  an NTFS reparse point only. Run with -WhatIf before removing that switch.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
  [ValidateNotNullOrEmpty()]
  [string]$LinkPath,

  [ValidateNotNullOrEmpty()]
  [string]$TargetPath,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  @'
Usage:
  pwsh -File Invoke-LcmJunctionCorrection.ps1 `
    -LinkPath <new LCM link path> -TargetPath <physical target> -WhatIf

The command creates a missing link or replaces an existing reparse point.
It fails rather than deleting a physical directory or linking to a reparse
point target. Remove -WhatIf only after reviewing the generated plan.
'@ | Write-Host
  return
}

if ([string]::IsNullOrWhiteSpace($LinkPath) -or [string]::IsNullOrWhiteSpace($TargetPath)) {
  throw 'Both -LinkPath and -TargetPath are required unless -Help is specified.'
}

$normalizedLinkPath = [System.IO.Path]::GetFullPath($LinkPath).TrimEnd('\')
$normalizedTargetPath = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
$parentPath = Split-Path -Path $normalizedLinkPath -Parent

if (-not (Test-Path -LiteralPath $normalizedTargetPath -PathType Container)) {
  throw "Target directory does not exist: $normalizedTargetPath"
}

$targetItem = Get-Item -LiteralPath $normalizedTargetPath -Force
if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw "Target must be a physical directory, not a reparse point: $normalizedTargetPath"
}

if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
  throw "Link parent directory does not exist: $parentPath"
}

$existingItem = Get-Item -LiteralPath $normalizedLinkPath -Force -ErrorAction SilentlyContinue
if ($null -ne $existingItem) {
  if (($existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
    throw "Refusing to replace physical path: $normalizedLinkPath"
  }

  if ($PSCmdlet.ShouldProcess($normalizedLinkPath, "Remove existing reparse point")) {
    $existingItem.Delete()
  }
}

if ($PSCmdlet.ShouldProcess($normalizedLinkPath, "Create junction to $normalizedTargetPath")) {
  New-Item -ItemType Junction -Path $normalizedLinkPath -Target $normalizedTargetPath | Out-Null
  $createdItem = Get-Item -LiteralPath $normalizedLinkPath -Force
  if (($createdItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0 -or
      -not (@($createdItem.Target) -contains $normalizedTargetPath)) {
    throw "Postcondition failed for junction: $normalizedLinkPath"
  }
}
