<#
.SYNOPSIS
  Automated workspace maintenance, log hygiene, and junk purge engine for LCM.
.DESCRIPTION
  Module: tools/Invoke-LCM_Maintenance.ps1
  Purpose: Enforces automated workspace hygiene, daemon log line truncation to a manageable tail (~100 lines),
           purges aged transient logs, and prunes temporary junk files without touching active BCR review scope.
           Designed to run standalone or as part of the pre-push pipeline in Invoke-LCM_Push.ps1.
  Path: LCM_Inventory/tools/Invoke-LCM_Maintenance.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.0.2
  Date: 2026-10-18
  Rule: RULE-PS-001 - RULE-PS-014, RULE-LCM-014
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Maximum lines to retain in active LcmDesktopDaemon-*.log files (default: 100)')]
    [int]$TailLines = 100,

    [Parameter(Mandatory = $false, HelpMessage = 'Maximum age in days for retaining daemon log files before deletion (default: 7)')]
    [int]$MaxLogAgeDays = 7,

    [Parameter(Mandatory = $false, HelpMessage = 'Maximum age in days for transient script logs in LCM_Inventory/data/logs/lcm (default: 3)')]
    [int]$MaxScriptLogAgeDays = 3,

    [Parameter(Mandatory = $false, HelpMessage = 'Maintain daemon and transient logs only; do not prune general temporary files')]
    [switch]$LogOnly,

    [Parameter(Mandatory = $false, HelpMessage = 'Execute cleanup in dry-run simulation mode without modifying or deleting files')]
    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM WORKSPACE MAINTENANCE & LOG HYGIENE ENGINE (Invoke-LCM_Maintenance)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Cleans LcmDesktopDaemon-*.log files to a ~100-line tail, purges stale transient logs,"
    Write-Host "  and optionally prunes temporary workspace junk. BCR review scope is never cleaned."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-LCM_Maintenance.ps1 [-TailLines <int>] [-MaxLogAgeDays <int>] [-MaxScriptLogAgeDays <int>] [-LogOnly] [-DryRun] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TailLines             : Number of lines to retain in daemon log files (default: 100)"
    Write-Host "  -MaxLogAgeDays         : Maximum age in days before deleting old daemon logs (default: 7)"
    Write-Host "  -MaxScriptLogAgeDays   : Maximum age in days for transient script logs (default: 3)"
    Write-Host "  -LogOnly               : Maintain daemon and transient logs without pruning temporary files"
    Write-Host "  -DryRun (-WhatIf)      : Simulate maintenance actions without mutating files"
    Write-Host "  -Help (-h, -?)         : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM WORKSPACE MAINTENANCE & LOG HYGIENE PIPELINE" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Tail Lines Target : $TailLines lines"
Write-Host " Daemon Log Max Age: $MaxLogAgeDays days"
Write-Host " Script Log Max Age: $MaxScriptLogAgeDays days"
Write-Host " Log Only          : $LogOnly"
Write-Host " Mode              : $(if ($DryRun) { 'SIMULATION (DryRun)' } else { 'APPLY (Mutating)' })"
Write-Host " Timestamp         : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================================================" -ForegroundColor Cyan

$stats = [PSCustomObject]@{
    DaemonLogsTrimmed   = 0
    DaemonLogsPurged    = 0
    DaemonBytesFreed    = [int64]0
    ScriptLogsPurged    = 0
    ScriptBytesFreed    = [int64]0
    ScratchJunkPurged   = 0
    ScratchBytesFreed   = [int64]0
}

# ------------------------------------------------------------------------------
# 1. Truncate & Purge LcmDesktopDaemon-*.log Files
# ------------------------------------------------------------------------------
Write-Host "`n[Step 1/3] Maintaining LCM Desktop Daemon Logs (Tail: $TailLines lines)..." -ForegroundColor Yellow

$daemonDirs = @(
    (Join-Path $workspaceRoot "LCM_Inventory\data\logs\lcm"),
    (Join-Path $workspaceRoot "LCM_Inventory\data\logs\lcm-internal"),
    (Join-Path $workspaceRoot "LCM_Inventory\tools\logs")
)

$cutoffDaemon = (Get-Date).AddDays(-$MaxLogAgeDays)

foreach ($dir in $daemonDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $logs = @(Get-ChildItem -Path $dir -Filter "LcmDesktopDaemon-*.log" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if ($logs.Count -eq 0) { continue }

    $newestLog = $logs[-1]

    foreach ($logFile in $logs) {
        # Check if aged out
        if ($logFile.LastWriteTime -lt $cutoffDaemon -and $logFile.FullName -ne $newestLog.FullName) {
            $fileSize = $logFile.Length
            Write-Host "  - Purging aged daemon log: $($logFile.Name) ($([math]::Round($fileSize / 1KB, 1)) KB, Modified: $($logFile.LastWriteTime.ToString('yyyy-MM-dd')))" -ForegroundColor DarkGray
            if (-not $DryRun) {
                Remove-Item -LiteralPath $logFile.FullName -Force -ErrorAction SilentlyContinue
            }
            $stats.DaemonLogsPurged++
            $stats.DaemonBytesFreed += $fileSize
            continue
        }

        # Check line count for truncation
        $contentLines = @(Get-Content -LiteralPath $logFile.FullName -ErrorAction SilentlyContinue)
        if ($contentLines.Count -gt $TailLines) {
            $origLen = $logFile.Length
            $tail = @($contentLines[($contentLines.Count - $TailLines)..($contentLines.Count - 1)])
            $truncHeader = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] [INFO] --- Log truncated by Workspace Maintenance (Retained last $($tail.Count) of $($contentLines.Count) lines) ---"
            $newLines = @($truncHeader) + $tail
            
            Write-Host "  - Truncating $($logFile.Name): $($contentLines.Count) lines ($([math]::Round($origLen / 1KB, 1)) KB) -> $($tail.Count) lines" -ForegroundColor Yellow
            if (-not $DryRun) {
                $written = $false
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    try {
                        [System.IO.File]::WriteAllLines($logFile.FullName, $newLines, [System.Text.Encoding]::UTF8)
                        $written = $true
                        break
                    } catch {
                        Start-Sleep -Milliseconds 60
                    }
                }
                if (-not $written) {
                    Write-Warning "Failed to truncate $($logFile.Name) due to file lock."
                }
            }

            $newLen = if (Test-Path -LiteralPath $logFile.FullName) { (Get-Item -LiteralPath $logFile.FullName).Length } else { 0 }
            $saved = [math]::Max([int64]0, $origLen - $newLen)
            $stats.DaemonLogsTrimmed++
            $stats.DaemonBytesFreed += $saved
        } else {
            Write-Host "  - Preserved $($logFile.Name): $($contentLines.Count) lines (within $TailLines threshold)" -ForegroundColor DarkGray
        }
    }
}

# ------------------------------------------------------------------------------
# 2. Purge Stale Transient Script Logs (LCM_Inventory/data/logs/lcm/*.log)
# ------------------------------------------------------------------------------
Write-Host "`n[Step 2/3] Purging Stale Script Logs in LCM_Inventory/data/logs/lcm (Older than $MaxScriptLogAgeDays days)..." -ForegroundColor Yellow

$lcmLogsDir = Join-Path $workspaceRoot "LCM_Inventory\data\logs\lcm"
if (Test-Path -LiteralPath $lcmLogsDir) {
    $scriptCutoff = (Get-Date).AddDays(-$MaxScriptLogAgeDays)
    $staleScriptLogs = @(Get-ChildItem -Path $lcmLogsDir -Filter "*.log" -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $scriptCutoff })
    
    if ($staleScriptLogs.Count -gt 0) {
        foreach ($sl in $staleScriptLogs) {
            $stats.ScriptBytesFreed += $sl.Length
            $stats.ScriptLogsPurged++
            if (-not $DryRun) {
                Remove-Item -LiteralPath $sl.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        $scriptLogAction = if ($DryRun) { 'Would purge' } else { 'Purged' }
        Write-Host "  - $scriptLogAction $($staleScriptLogs.Count) transient script logs ($([math]::Round($stats.ScriptBytesFreed / 1KB, 1)) KB eligible)" -ForegroundColor Green
    } else {
        Write-Host "  - No stale transient script logs found older than $MaxScriptLogAgeDays days." -ForegroundColor DarkGray
    }
}

if ($LogOnly) {
    $totalFreedKb = [math]::Round(($stats.DaemonBytesFreed + $stats.ScriptBytesFreed) / 1KB, 1)
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host " LOG-ONLY MAINTENANCE SUMMARY" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " Daemon Logs Truncated : $($stats.DaemonLogsTrimmed)"
    Write-Host " Daemon Logs Purged    : $($stats.DaemonLogsPurged)"
    Write-Host " Script Logs Purged    : $($stats.ScriptLogsPurged)"
    Write-Host " Total Storage Freed   : $totalFreedKb KB ($([math]::Round($totalFreedKb / 1024, 2)) MB)" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return $stats
}

# ------------------------------------------------------------------------------
# 3. Prune Temporary Junk Files (*.tmp, *~, scratch temp)
# ------------------------------------------------------------------------------
Write-Host "`n[Step 3/3] Pruning Temporary Workspace Junk (*.tmp, *~)..." -ForegroundColor Yellow

$scratchDir = Join-Path $workspaceRoot "LCM_Inventory\scratch"
if (Test-Path -LiteralPath $scratchDir) {
    $junkCutoff = (Get-Date).AddHours(-24)
    # Search for non-junction loose temp files
    $junkFiles = @(Get-ChildItem -Path $scratchDir -File -ErrorAction SilentlyContinue | Where-Object {
        ($_.Extension -in @('.tmp', '.bak') -or $_.Name -like '*~*') -and
        $_.LastWriteTime -lt $junkCutoff -and
        $_.Name -ne 'tool_catalog.json.bak'
    })

    if ($junkFiles.Count -gt 0) {
        foreach ($jf in $junkFiles) {
            $stats.ScratchBytesFreed += $jf.Length
            $stats.ScratchJunkPurged++
            if (-not $DryRun) {
                Remove-Item -LiteralPath $jf.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  - Purged $($junkFiles.Count) temporary junk files ($([math]::Round($stats.ScratchBytesFreed / 1KB, 1)) KB freed)" -ForegroundColor Green
    } else {
        Write-Host "  - No temporary junk files (*.tmp, *~) found older than 24 hours." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 5. Maintenance Summary Report
# ------------------------------------------------------------------------------
$totalFreedKb = [math]::Round(($stats.DaemonBytesFreed + $stats.ScriptBytesFreed + $stats.ScratchBytesFreed) / 1KB, 1)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " WORKSPACE MAINTENANCE SUMMARY REPORT" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Daemon Logs Truncated : $($stats.DaemonLogsTrimmed)"
Write-Host " Daemon Logs Purged    : $($stats.DaemonLogsPurged)"
Write-Host " Script Logs Purged    : $($stats.ScriptLogsPurged)"
Write-Host " Scratch Junk Purged   : $($stats.ScratchJunkPurged)"
Write-Host " Total Storage Freed   : $totalFreedKb KB ($([math]::Round($totalFreedKb / 1024, 2)) MB)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
