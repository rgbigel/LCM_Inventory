<#
.SYNOPSIS
Updates the modified time of folders to the latest modified time of files and subfolders contained within.

.DESCRIPTION
Module: LCM_Tools/tools/FolderTimeUpdate.ps1
Purpose: Launches NirSoft FolderTimeUpdate utility to scan folders and recalculate their Modified timestamps based on newest child contents.
Role: DesktopGUI
Audience: User
Path: LCM_Tools/tools/FolderTimeUpdate.ps1
Authors: Rolf, Antigravity
Version: 1.0.1
Date: 2026-11-11

.PARAMETER Path
Base directory path to process with FolderTimeUpdate.

.PARAMETER Help
Displays help documentation and usage syntax (Aliases: -h, -?).

.EXAMPLE
FolderTimeUpdate -Path "D:\Git_Repositories"
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Base directory path to process with FolderTimeUpdate.")]
  [string]$Path = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "# [LCM] FolderTimeUpdate - Goal: Updates folder modified timestamps to match latest contained child elements." -ForegroundColor Cyan

$exeCandidates = @(
  'D:\WSCC4\NirSoft Utilities\x64\FolderTimeUpdate.exe',
  'D:\OneDrive\Documents\Einstellungen\InstalledAppsList\x64\FolderTimeUpdate.exe'
)

$targetExe = $null
foreach ($candidate in $exeCandidates) {
  if (Test-Path -LiteralPath $candidate) {
    $targetExe = $candidate
    break
  }
}

if (-not $targetExe) {
  throw "FolderTimeUpdate.exe not found in known installation paths."
}

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " FOLDER TIME UPDATE (FolderTimeUpdate)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Updates folder modified timestamps based on newest contained child elements."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  FolderTimeUpdate [[-Path] <directory>]"
  Write-Host "  pwsh -File tools/FolderTimeUpdate.ps1 [-Path <directory>] [-h]"
  Write-Host ""
  Write-Host "EXECUTABLE LOCATION:" -ForegroundColor Yellow
  Write-Host "  $targetExe"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$argList = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrWhiteSpace($Path)) {
  $argList.Add("/BaseFolder `"$Path`"")
}

if ($argList.Count -gt 0) {
  Start-Process -FilePath $targetExe -ArgumentList ($argList -join ' ')
} else {
  Start-Process -FilePath $targetExe
}

