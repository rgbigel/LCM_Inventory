<#
.SYNOPSIS
  Archives active LCM Desktop Daemon logs without modifying their sources.
.DESCRIPTION
  Copies daemon logs into a timestamped Inventory archive before a publish or
  maintenance action can truncate or purge them.
.PARAMETER ArchiveRoot
  Optional destination root. Defaults to LCM_Inventory/data/archives/daemon-logs.
.PARAMETER DryRun
  Reports the archive that would be created without writing files.
.PARAMETER Help
  Displays command help.
.NOTES
  Module: Archive-LcmDaemonLogs
  Path: LCM_Inventory/tools/Archive-LcmDaemonLogs.ps1
  Version: 10.0.0
  Date: 2026-10-13
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Optional daemon-log archive root.')]
  [string]$ArchiveRoot = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Report archive actions without writing files.')]
  [switch]$DryRun,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptName = 'Archive-LcmDaemonLogs'
$scriptVersion = '10.0.0'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host " LCM DAEMON LOG ARCHIVE (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Copies active daemon log evidence into a timestamped archive without'
  Write-Host '  truncating, deleting, or moving the source logs.'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  ArchiveLcmDaemonLogs [-ArchiveRoot <path>] [-DryRun] [-h]'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LCM_Context.psm1'
Import-Module -Name $modulePath -Force
$gitRoot = Get-LcmMachineGitRoot
$inventoryRoot = Join-Path $gitRoot 'LCM_Inventory'
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
  $ArchiveRoot = Join-Path $inventoryRoot 'data\archives\daemon-logs'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$archiveDirectory = Join-Path $ArchiveRoot $timestamp
$sourceDirectories = [ordered]@{
  'lcm' = Join-Path $inventoryRoot 'data\logs\lcm'
  'lcm-internal' = Join-Path $inventoryRoot 'data\logs\lcm-internal'
}

$sourceFiles = foreach ($sourceName in $sourceDirectories.Keys) {
  $sourceDirectory = $sourceDirectories[$sourceName]
  if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
    continue
  }
  Get-ChildItem -LiteralPath $sourceDirectory -File |
    Where-Object { $_.Name -like 'LcmDesktopDaemon-*.log' -or $_.Name -eq 'lcm_daemon.log' } |
    ForEach-Object {
      [pscustomobject]@{
        SourceName = $sourceName
        File = $_
      }
    }
}

if (@($sourceFiles).Count -eq 0) {
  Write-Warning 'No daemon logs were found to archive.'
  return [pscustomobject]@{
    ArchivePath = $archiveDirectory
    FilesSelected = 0
    FilesArchived = 0
    DryRun = [bool]$DryRun
  }
}

$filesArchived = 0
$bytesArchived = [int64]0
if (-not $DryRun) {
  New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
}

foreach ($sourceFile in $sourceFiles) {
  $destinationDirectory = Join-Path $archiveDirectory $sourceFile.SourceName
  $destinationPath = Join-Path $destinationDirectory $sourceFile.File.Name
  if ($DryRun) {
    Write-Host "  [DRY RUN] Archive $($sourceFile.File.FullName) -> $destinationPath" -ForegroundColor Yellow
    continue
  }

  if ($PSCmdlet.ShouldProcess($sourceFile.File.FullName, "Archive to $destinationPath")) {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    $sourceStream = [System.IO.File]::Open($sourceFile.File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      $destinationStream = [System.IO.File]::Create($destinationPath)
      try {
        $sourceStream.CopyTo($destinationStream)
      } finally {
        $destinationStream.Dispose()
      }
    } finally {
      $sourceStream.Dispose()
    }
    $filesArchived++
    $bytesArchived += (Get-Item -LiteralPath $destinationPath).Length
  }
}

$manifest = [ordered]@{
  archive_created_at = (Get-Date).ToString('o')
  git_root = $gitRoot
  source_directories = $sourceDirectories
  files_selected = @($sourceFiles).Count
  files_archived = $filesArchived
  bytes_archived = $bytesArchived
  source_files = @($sourceFiles | ForEach-Object { $_.File.FullName })
}
if (-not $DryRun) {
  $manifestPath = Join-Path $archiveDirectory 'archive_manifest.json'
  [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4), [System.Text.UTF8Encoding]::new($false))
}

Write-Host "Archived $filesArchived daemon log file(s) to $archiveDirectory." -ForegroundColor Green
return [pscustomobject]@{
  ArchivePath = $archiveDirectory
  FilesSelected = @($sourceFiles).Count
  FilesArchived = $filesArchived
  BytesArchived = $bytesArchived
  DryRun = [bool]$DryRun
}
