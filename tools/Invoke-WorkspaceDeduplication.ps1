<#
.SYNOPSIS
  High-performance hash-based workspace artifact deduplication and archive consolidation engine.
.DESCRIPTION
  Module: tools/Invoke-WorkspaceDeduplication.ps1
  Purpose: Identifies duplicate files across workspace directories using SHA-256 / CRC-64 hashing,
           preserves the newest/canonical instance in its active path, and safely moves redundant
           duplicates into dedicated structured \archive folders without deleting any content.
  Path: Workspace_Inventory/tools/Invoke-WorkspaceDeduplication.ps1
  Authors: Rolf, Workspace_AI Engine
  Version: 1.0.0
  Date: 2026-08-30
  Conforms to: RULE-PS-008, RULE-PS-009, RULE-PS-010, RULE-LCM-001 - RULE-LCM-013
.PARAMETER Apply
  Executes the archival moves. Without -Apply, runs in safe -AuditOnly (dry-run) mode.
.PARAMETER AuditOnly
  Explicit dry-run mode that calculates hashes and displays duplicate clusters without moving files.
.PARAMETER TargetDirectories
  Explicit directories to scan for duplicates. Defaults to workspace data, scratch, and staging folders.
.PARAMETER ArchiveRoot
  Base directory where archived duplicates will be stored.
.PARAMETER LogFile
  Custom log file destination. Defaults to Workspace_Inventory/logs/Invoke-WorkspaceDeduplication-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Invoke-WorkspaceDeduplication.ps1 -h
.EXAMPLE
  pwsh tools/Invoke-WorkspaceDeduplication.ps1 -AuditOnly
.EXAMPLE
  pwsh tools/Invoke-WorkspaceDeduplication.ps1 -Apply
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Apply,
    [switch]$AuditOnly,
    [string[]]$TargetDirectories,
    [string]$ArchiveRoot,
    [string]$LogFile = "",
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.0.0"
$scriptName = "Invoke-WorkspaceDeduplication"
$workspaceRoot = 'D:\Git_Repositories'

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " WORKSPACE ARTIFACT DEDUPLICATION & ARCHIVE ENGINE (v$($scriptVersion))" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Discovers identical file instances using cryptographic SHA-256 hashing,"
    Write-Host "  preserves the newest canonical version, and safely moves redundant duplicates"
    Write-Host "  to structured \archive folders with zero permanent deletions."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-WorkspaceDeduplication.ps1 [-AuditOnly] [-Apply] [-TargetDirectories <dirs>] [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

# ------------------------------------------------------------------------------
# 1. Audit Logging Setup per RULE-PS-009
# ------------------------------------------------------------------------------
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $logDir = Join-Path $workspaceRoot "Workspace_Inventory\logs"
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $LogFile = Join-Path $logDir "Invoke-WorkspaceDeduplication-$timestamp.log"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logLine = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'))] [$Level] $Message"
    Add-Content -LiteralPath $LogFile -Value $logLine -Encoding UTF8
    switch ($Level) {
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "WARN"    { Write-Host $Message -ForegroundColor Yellow }
        "ACTION"  { Write-Host $Message -ForegroundColor Green }
        "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
        default   { Write-Host $Message -ForegroundColor Gray }
    }
}

$isDryRun = (-not $Apply) -or $AuditOnly

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " WORKSPACE ARTIFACT DEDUPLICATION & ARCHIVE ENGINE (v$($scriptVersion))" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Execution Mode : $(if ($isDryRun) { 'AUDIT ONLY (Dry Run)' } else { 'APPLY (Archiving)' })"
Write-Host " Log File       : $LogFile"
Write-Host " Timestamp      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================================================" -ForegroundColor Cyan

Write-Log "Starting Workspace Deduplication Run in $(if ($isDryRun) { 'AuditOnly' } else { 'Apply' }) mode."

# ------------------------------------------------------------------------------
# 2. Targeted Candidate Scopes
# ------------------------------------------------------------------------------
$scanDirs = [System.Collections.Generic.List[string]]::new()
if ($TargetDirectories -and $TargetDirectories.Count -gt 0) {
    foreach ($td in $TargetDirectories) {
        $p = if ([System.IO.Path]::IsPathRooted($td)) { $td } else { Join-Path $workspaceRoot $td }
        if (Test-Path -LiteralPath $p) { $scanDirs.Add($p) }
    }
} else {
    $candidates = @(
        (Join-Path $workspaceRoot "Workspace_Inventory\data"),
        (Join-Path $workspaceRoot "Workspace_Inventory\scratch"),
        (Join-Path $workspaceRoot "HaSSD06\scratch"),
        (Join-Path $workspaceRoot "HaSSD06_Inventory\scratch"),
        (Join-Path $workspaceRoot "HaSSD06_Inventory\docs"),
        (Join-Path $workspaceRoot ".lcm\tools\links")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $scanDirs.Add($c) }
    }
}

Write-Log "Scanning $(@($scanDirs).Count) targeted directories for candidate duplicates..."

$allFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($sd in $scanDirs) {
    $found = Get-ChildItem -Path $sd -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch "\\\.git\\" -and
        $_.FullName -notmatch "\\\.venv\\" -and
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\data\\archives\\"
    }
    foreach ($f in $found) {
        $allFiles.Add($f)
    }
}

Write-Log "Discovered $(@($allFiles).Count) eligible artifacts for hashing analysis."

# ------------------------------------------------------------------------------
# 3. Hash Grouping & Cluster Analysis
# ------------------------------------------------------------------------------
$bySize = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 -and [int64]$_.Name -gt 0 }
Write-Log "Identified $(@($bySize).Count) size groups containing candidate duplicates."

$clusters = [System.Collections.Generic.List[object]]::new()
$processedFiles = 0
$totalCandidateFiles = ($bySize | Measure-Object -Property Count -Sum).Sum

foreach ($szGroup in $bySize) {
    $byHash = $szGroup.Group | Group-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    foreach ($hg in $byHash) {
        if ($hg.Count -gt 1) {
            # Sort: Active primary locations preferred, then newest LastWriteTime
            $sorted = $hg.Group | Sort-Object `
                @{ Expression = { if ($_.FullName -match "\\scratch\\|\\links\\") { 1 } else { 0 } }; Ascending = $true }, `
                @{ Expression = { $_.LastWriteTime }; Ascending = $false }

            $canonical = $sorted[0]
            $redundant = @($sorted | Select-Object -Skip 1)

            $clusters.Add([PSCustomObject]@{
                Hash        = $hg.Name
                FileSize    = $canonical.Length
                TotalCount  = $hg.Count
                Canonical   = $canonical.FullName
                Duplicates  = @($redundant | ForEach-Object { $_.FullName })
            })
        }
    }
}

Write-Log "Identified $(@($clusters).Count) duplicate clusters ($( ($clusters | ForEach-Object { $_.Duplicates.Count } | Measure-Object -Sum).Sum ) redundant instances)." "SUMMARY"

# ------------------------------------------------------------------------------
# 4. Archival Execution per Invariant Standard (Zero Deletions)
# ------------------------------------------------------------------------------
$archivedCount = 0
$savedBytes = 0

foreach ($cluster in $clusters) {
    Write-Host "`n[Hash: $($cluster.Hash.Substring(0, 12))... | Size: $($cluster.FileSize) bytes | Total: $($cluster.TotalCount)]" -ForegroundColor Yellow
    Write-Host "  [CANONICAL KEEP] $($cluster.Canonical)" -ForegroundColor Green

    foreach ($dupPath in $cluster.Duplicates) {
        # Determine appropriate \archive destination
        $relPath = $dupPath.Substring($workspaceRoot.Length).TrimStart('\', '/')
        $repoSegment = $relPath.Split('\')[0]
        $archiveTargetDir = Join-Path $workspaceRoot "$repoSegment\data\archives\deduplicated_snapshots"
        
        if ($dupPath -match "\\\.lcm\\tools\\links\\") {
            $archiveTargetDir = Join-Path $workspaceRoot ".lcm\archive\tools_links_backup"
        } elseif ($dupPath -match "\\scratch\\BC_Review\\") {
            $archiveTargetDir = Join-Path $workspaceRoot "Workspace_Inventory\data\archives\BC_Review_Snapshots"
        }

        $destFile = Join-Path $archiveTargetDir ([System.IO.Path]::GetFileName($dupPath))
        
        # Handle collision in archive directory with timestamp suffix
        if (Test-Path -LiteralPath $destFile) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($dupPath)
            $ext = [System.IO.Path]::GetExtension($dupPath)
            $destFile = Join-Path $archiveTargetDir "${base}_archived_${timestamp}${ext}"
        }

        if (-not $isDryRun) {
            if (-not (Test-Path -LiteralPath $archiveTargetDir)) {
                New-Item -ItemType Directory -Path $archiveTargetDir -Force | Out-Null
            }
            Move-Item -LiteralPath $dupPath -Destination $destFile -Force
            Write-Log "  -> Moved to archive: $destFile" "ACTION"
        } else {
            Write-Host "  [DRY-RUN MOVE] $dupPath  -->  $destFile" -ForegroundColor DarkGray
        }

        $archivedCount++
        $savedBytes += $cluster.FileSize
    }
}

# ------------------------------------------------------------------------------
# 5. Summary Report
# ------------------------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Workspace Deduplication & Archival Completed" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Clusters Processed  : $(@($clusters).Count)"
Write-Host " Redundant Artifacts : $archivedCount"
Write-Host " Active Space Saved  : $([math]::Round($savedBytes / 1MB, 2)) MB ($savedBytes bytes)"
Write-Host " Execution Mode      : $(if ($isDryRun) { 'DRY RUN (0 files modified)' } else { 'APPLIED (All moved to \archive)' })"
Write-Host " Log File            : $LogFile"
Write-Host "==========================================================================" -ForegroundColor Cyan

Write-Log "Deduplication finished. Archived: $archivedCount, Saved: $savedBytes bytes." "SUMMARY"
