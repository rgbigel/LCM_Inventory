<#
.SYNOPSIS
  Recursively copies files with robust path handling, folder exclusions, and execution logging.
.DESCRIPTION
  Module: tools/Safe-Copy.ps1
  Purpose: Copies files from source to target with error recovery, optional exclusion masks, and audit logging.
  Path: tools/Safe-Copy.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER SourcePath
  Source directory path to copy files from (default 'F:\OneDrive').
.PARAMETER TargetPath
  Target destination directory path (default 'J:\OneDrive_Safe').
.PARAMETER ExtraSkip
  Optional directory name prefix or mask to skip during copying.
.PARAMETER TraceMode
  Enables verbose step tracing (Aliases: -t, -Trace).
.PARAMETER Help
  Displays parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Safe-Copy.ps1 -SourcePath "D:\Data" -TargetPath "E:\Backup\Data"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$SourcePath = "F:\OneDrive",

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$TargetPath = "J:\OneDrive_Safe",

  [Parameter(Mandatory = $false)]
  [string]$ExtraSkip = "",

  [Alias('t', 'Trace')]
  [switch]$TraceMode,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Safe-Copy"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " SAFE RECURSIVE FILE COPIER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Safely copies recursive directory structures with skip filters and audit logging."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Safe-Copy.ps1 [-SourcePath <path>] [-TargetPath <path>] [-ExtraSkip <dir>] [-t] [-h]"
  return
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
  Write-Error "Source path does not exist: $SourcePath"
  exit 1
}

if (-not (Test-Path -LiteralPath $TargetPath)) {
  New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

$logDir = "D:\Git_Repositories\LCM_Tools\logs"
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir ("SafeCopy-{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

$okCount = 0
$failCount = 0
$skipCount = 0

Write-Host "Starting Safe-Copy: '$SourcePath' -> '$TargetPath'..." -ForegroundColor Cyan

$files = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -File)
foreach ($file in $files) {
  $src = $file.FullName
  $relative = $src.Substring($SourcePath.Length).TrimStart('\')
  if ($ExtraSkip -and $relative.StartsWith($ExtraSkip, [System.StringComparison]::OrdinalIgnoreCase)) {
    Add-Content -LiteralPath $logFile -Value ("[SKIP] {0}" -f $src)
    $skipCount++
    continue
  }

  $dest = Join-Path $TargetPath $relative
  $destDir = Split-Path $dest -Parent
  if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
  }

  try {
    Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
    Add-Content -LiteralPath $logFile -Value ("[OK] {0} -> {1}" -f $src, $dest)
    $okCount++
    if ($TraceMode) { Write-Host "  [OK] $relative" -ForegroundColor DarkGray }
  } catch {
    Add-Content -LiteralPath $logFile -Value ("[FAIL] {0} : {1}" -f $src, $_.Exception.Message)
    Write-Host "  [FAIL] $relative : $($_.Exception.Message)" -ForegroundColor Red
    $failCount++
  }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SAFE COPY SUMMARY" -ForegroundColor Cyan
Write-Host " Copied : $okCount" -ForegroundColor $(if ($okCount -gt 0) { 'Green' } else { 'Yellow' })
Write-Host " Skipped: $skipCount"
Write-Host " Failed : $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Host " Log    : $logFile" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
