<#
.SYNOPSIS
  Splits a large text file into numbered chunks without breaking lines.
.DESCRIPTION
  Module: tools/Split-TextFile.ps1
  Purpose: Splits a text file into numbered parts without breaking individual lines.
           Each part is limited by a maximum character count.
  Path: tools/Split-TextFile.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER InputFile
  Path to the input text file to split.
.PARAMETER MaxChars
  Maximum character count per split chunk (default 6000).
.PARAMETER OutputDirectory
  Optional output directory. Defaults to a 'Parts' subfolder next to the input file.
.PARAMETER TraceMode
  Enables verbose step tracing (Aliases: -t, -Trace).
.PARAMETER Help
  Displays parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Split-TextFile.ps1 -InputFile "D:\Logs\large_log.txt" -MaxChars 8000
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$InputFile,

  [Parameter(Mandatory = $false, Position = 1)]
  [int]$MaxChars = 6000,

  [Parameter(Mandatory = $false)]
  [string]$OutputDirectory = "",

  [Alias('t', 'Trace')]
  [switch]$TraceMode,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Split-TextFile"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " TEXT FILE SPLITTER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Splits a text file into numbered line-safe chunks."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Split-TextFile.ps1 -InputFile <path> [-MaxChars <int>] [-OutputDirectory <dir>] [-t] [-h]"
  return
}

if (-not (Test-Path -LiteralPath $InputFile)) {
  Write-Error "Input file does not exist: $InputFile"
  exit 1
}

$lines = Get-Content -LiteralPath $InputFile -ErrorAction Stop

$outDir = if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory
} else {
  Join-Path (Split-Path -Parent $InputFile) 'Parts'
}

if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$buf = [System.Text.StringBuilder]::new()
$idx = 1
$createdFiles = @()

foreach ($line in $lines) {
  $add = $line + [System.Environment]::NewLine
  if (($buf.Length + $add.Length) -gt $MaxChars -and $buf.Length -gt 0) {
    $chunkName = '{0:D3}.txt' -f $idx
    $chunkPath = Join-Path $outDir $chunkName
    [System.IO.File]::WriteAllText($chunkPath, $buf.ToString(), [System.Text.Encoding]::UTF8)
    $createdFiles += $chunkPath
    if ($TraceMode) { Write-Host "  [Chunk $idx] $chunkPath ($($buf.Length) chars)" -ForegroundColor DarkGray }
    $buf.Clear() | Out-Null
    $idx++
  }
  $null = $buf.Append($add)
}

if ($buf.Length -gt 0) {
  $chunkName = '{0:D3}.txt' -f $idx
  $chunkPath = Join-Path $outDir $chunkName
  [System.IO.File]::WriteAllText($chunkPath, $buf.ToString(), [System.Text.Encoding]::UTF8)
  $createdFiles += $chunkPath
  if ($TraceMode) { Write-Host "  [Chunk $idx] $chunkPath ($($buf.Length) chars)" -ForegroundColor DarkGray }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SPLIT TEXT FILE SUMMARY" -ForegroundColor Cyan
Write-Host " Input File   : $InputFile"
Write-Host " Chunks Created: $($createdFiles.Count)" -ForegroundColor Green
Write-Host " Output Folder: $outDir" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
