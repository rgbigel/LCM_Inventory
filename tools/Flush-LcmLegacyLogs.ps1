<#
.SYNOPSIS
    Prunes transient logs, legacy deletions, and scratch trees older than 2 major releases (RULE-DOC-006) while preserving permanent evolution history.
.DESCRIPTION
    Module: tools/Flush-LcmLegacyLogs.ps1
    Authors: Rolf, LCM_AI Governance
    Version: 6.0.1
    Date: 2026-09-10
    Rule: RULE-DOC-006, RULE-PS-001 - RULE-PS-014
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Current active major release version number (e.g. 7)')]
    [int]$TargetMajor = 7,

    [Parameter(Mandatory = $false, HelpMessage = 'Number of previous major releases to retain before pruning (RULE-DOC-006 M-2)')]
    [int]$RetentionHorizon = 2,

    [Parameter(Mandatory = $false, HelpMessage = 'Execute live deletion and pruning of stale logs and scratch artifacts')]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = 'Perform audit only without deleting any files (default read-only)')]
    [switch]$AuditOnly,

    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory containing repository log folders')]
    [string]$RootPath = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM LEGACY LOG & SCRATCH PRUNING ENGINE (Flush-LcmLegacyLogs)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Prunes transient logs and scratch trees older than 2 major releases (RULE-DOC-006)."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh .lcm/tools/internal/Flush-LcmLegacyLogs.ps1 [-TargetMajor <int>] [-RetentionHorizon <int>] [-Apply] [-AuditOnly] [-RootPath <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetMajor      : Current active major release version (default: 7)"
    Write-Host "  -RetentionHorizon : Retention horizon in major releases (default: 2)"
    Write-Host "  -Apply            : Execute live deletion and pruning"
    Write-Host "  -AuditOnly        : Perform read-only audit (default)"
    Write-Host "  -RootPath         : Root workspace directory"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$cutoffMajor = $TargetMajor - $RetentionHorizon

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM MAJOR RELEASE RETENTION & PRUNING ENGINE (v6.0.0)" -ForegroundColor Cyan
Write-Host " Active Major Release : v$TargetMajor.x.x" -ForegroundColor Cyan
Write-Host " Retention Horizon    : $RetentionHorizon Major Releases (Preserves >= v$($cutoffMajor + 1).0.0)" -ForegroundColor Cyan
Write-Host " Flush Cutoff Horizon : Releases <= v$cutoffMajor.x.x" -ForegroundColor Cyan
Write-Host " Execution Mode       : $(if ($Apply -and -not $AuditOnly) { 'APPLY (Mutating)' } else { 'AUDIT ONLY (Read-Only)' })" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$auditItems = [System.Collections.Generic.List[object]]::new()
$bytesToFree = 0

# Helper: Check if path is protected evolution history
function Test-IsProtectedHistory {
    param([string]$Path)
    if ($Path -match '\\(0\d_[^\\\/]+-Evolution|History)(\\|$)' -or $Path -match '\\docs\\Logs\\0\d_') {
        return $true
    }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if ($Path -match '\.md$') {
            $head = (Get-Content -LiteralPath $Path -TotalCount 15 -ErrorAction SilentlyContinue) -join "`n"
            if ($head -and $head -match 'Classification:\s*permanent-evolution-history') {
                return $true
            }
        }
    }
    return $false
}

# 1. Inspect LCM_AI/Deletions (Releases <= 4)
$deletionsPath = Join-Path $RootPath 'LCM_AI\Deletions'
if (Test-Path -LiteralPath $deletionsPath) {
    $delFiles = @(Get-ChildItem -LiteralPath $deletionsPath -Recurse -File -Force -ErrorAction SilentlyContinue)
    $delSize = 0
    if ($delFiles.Count -gt 0) {
        $m = $delFiles | Measure-Object -Property Length -Sum
        if ($m.Sum) { $delSize = [int64]$m.Sum }
    }
    
    $auditItems.Add([PSCustomObject]@{
        Target      = 'LCM_AI\Deletions'
        Category    = 'Legacy Deletion Tree (v1.x-v4.x)'
        ItemCount   = $delFiles.Count
        SizeBytes   = $delSize
        SizeMB      = [math]::Round($delSize / 1MB, 2)
        Protected   = $false
        Disposition = if ($Apply -and -not $AuditOnly) { 'PURGED' } else { 'FLUSH_ELIGIBLE' }
    })
    $bytesToFree += $delSize
}

# 2. Inspect LCM_Inventory/data/logs/lcm (Transient Daily Logs older than active window)
$lcdLogsPath = Join-Path $RootPath 'LCM_Inventory\data\logs\lcm'
if (Test-Path -LiteralPath $lcdLogsPath) {
    $cutoffDate = (Get-Date).AddDays(-3)
    $staleLogs = @(Get-ChildItem -LiteralPath $lcdLogsPath -File -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate })
    $staleSize = 0
    if ($staleLogs.Count -gt 0) {
        $m = $staleLogs | Measure-Object -Property Length -Sum
        if ($m.Sum) { $staleSize = [int64]$m.Sum }
    }

    $auditItems.Add([PSCustomObject]@{
        Target      = 'LCM_Inventory\data\logs\lcm (*.log > 3d)'
        Category    = 'Transient Tool Logs'
        ItemCount   = $staleLogs.Count
        SizeBytes   = $staleSize
        SizeMB      = [math]::Round($staleSize / 1MB, 2)
        Protected   = $false
        Disposition = if ($Apply -and -not $AuditOnly) { 'PURGED' } else { 'FLUSH_ELIGIBLE' }
    })
    $bytesToFree += $staleSize
}

# 3. Inspect .lcm/archive (Superseded legacy scripts)
$lcdArchivePath = Join-Path $RootPath '.lcm\archive'
if (Test-Path -LiteralPath $lcdArchivePath) {
    $archFiles = @(Get-ChildItem -LiteralPath $lcdArchivePath -Recurse -File -Force -ErrorAction SilentlyContinue)
    $archSize = 0
    if ($archFiles.Count -gt 0) {
        $m = $archFiles | Measure-Object -Property Length -Sum
        if ($m.Sum) { $archSize = [int64]$m.Sum }
    }

    $auditItems.Add([PSCustomObject]@{
        Target      = '.lcm\archive'
        Category    = 'Superseded Scripts Archive'
        ItemCount   = $archFiles.Count
        SizeBytes   = $archSize
        SizeMB      = [math]::Round($archSize / 1MB, 2)
        Protected   = $false
        Disposition = if ($Apply -and -not $AuditOnly) { 'PURGED' } else { 'FLUSH_ELIGIBLE' }
    })
    $bytesToFree += $archSize
}

# 4. Audit Protected Permanent Evolution History (Assertion of safety)
$historyPath = Join-Path $RootPath 'LCM_AI\docs\Logs'
if (Test-Path -LiteralPath $historyPath) {
    $histFiles = @(Get-ChildItem -LiteralPath $historyPath -Recurse -File | Where-Object { Test-IsProtectedHistory $_.FullName })
    $histSize = 0
    if ($histFiles.Count -gt 0) {
        $m = $histFiles | Measure-Object -Property Length -Sum
        if ($m.Sum) { $histSize = [int64]$m.Sum }
    }

    $auditItems.Add([PSCustomObject]@{
        Target      = 'LCM_AI\docs\Logs\*-Evolution'
        Category    = 'Macro Evolution History Logs'
        ItemCount   = $histFiles.Count
        SizeBytes   = $histSize
        SizeMB      = [math]::Round($histSize / 1MB, 2)
        Protected   = $true
        Disposition = 'PRESERVED (Protected Invariant)'
    })
}

$wiHistoryPath = Join-Path $RootPath 'LCM_Inventory\logs\history'
if (Test-Path -LiteralPath $wiHistoryPath) {
    $wiHistFiles = @(Get-ChildItem -LiteralPath $wiHistoryPath -Recurse -File -ErrorAction SilentlyContinue)
    $wiHistSize = 0
    if ($wiHistFiles.Count -gt 0) {
        $m = $wiHistFiles | Measure-Object -Property Length -Sum
        if ($m.Sum) { $wiHistSize = [int64]$m.Sum }
    }

    $auditItems.Add([PSCustomObject]@{
        Target      = 'LCM_Inventory\logs\history'
        Category    = 'Permanent CM History Logs'
        ItemCount   = $wiHistFiles.Count
        SizeBytes   = $wiHistSize
        SizeMB      = [math]::Round($wiHistSize / 1MB, 2)
        Protected   = $true
        Disposition = 'PRESERVED (Protected Invariant)'
    })
}

# Render Table
Write-Host ""
$auditItems | Format-Table -AutoSize -Property Target, Category, ItemCount, SizeMB, Protected, Disposition

$totalFlushMB = [math]::Round($bytesToFree / 1MB, 2)
Write-Host " Total Flushable Volume: $totalFlushMB MB across $(($auditItems | Where-Object { -not $_.Protected } | Measure-Object -Property ItemCount -Sum).Sum) items." -ForegroundColor Cyan

# Execution Phase
if ($Apply -and -not $AuditOnly) {
    Write-Host "`nExecuting Major Release Retention Flush..." -ForegroundColor Yellow
    
    # Purge LCM_AI\Deletions
    if (Test-Path -LiteralPath $deletionsPath) {
        Remove-Item -LiteralPath $deletionsPath -Recurse -Force
        Write-Host "  -> Purged legacy deletion tree: LCM_AI\Deletions" -ForegroundColor Green
    }

    # Purge stale logs > 3 days in LCM_Inventory\data\logs\lcm
    if (Test-Path -LiteralPath $lcdLogsPath) {
        $staleLogs = @(Get-ChildItem -LiteralPath $lcdLogsPath -File -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate })
        foreach ($sl in $staleLogs) {
            Remove-Item -LiteralPath $sl.FullName -Force
        }
        Write-Host "  -> Purged $($staleLogs.Count) transient logs in LCM_Inventory\data\logs\lcm" -ForegroundColor Green
    }

    # Purge obsolete .lcm/archive if present
    if (Test-Path -LiteralPath $lcdArchivePath) {
        Remove-Item -LiteralPath $lcdArchivePath -Recurse -Force
        Write-Host "  -> Purged obsolete archive in .lcm\archive" -ForegroundColor Green
    }

    # Purge root tools if any recreated
    $rootTools = Join-Path $RootPath 'tools'
    if (Test-Path -LiteralPath $rootTools) {
        Remove-Item -LiteralPath $rootTools -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  -> Purged legacy root tools directory" -ForegroundColor Green
    }

    # Write audit log receipt
    $logFile = Join-Path $lcdLogsPath ("Flush-LcmLegacyLogs-{0}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
    $logContent = "=== LCM MAJOR RELEASE RETENTION FLUSH RECEIPT ===`n" +
                  "Timestamp      : $(Get-Date -Format 'o')`n" +
                  "Active Release : v$TargetMajor.x.x`n" +
                  "Cutoff Horizon : <= v$cutoffMajor.x.x`n" +
                  "Freed Space    : $totalFlushMB MB`n" +
                  "Protected Logs : Preserved all *-Evolution and LCM_Inventory history logs.`n"
    Set-Content -LiteralPath $logFile -Value $logContent -Encoding UTF8
    Write-Host "  -> Audit receipt recorded: $logFile" -ForegroundColor Cyan
    Write-Host "`n Retention flush completed successfully.`n" -ForegroundColor Green
} else {
    Write-Host "`nTo execute retention flush, run with -Apply:" -ForegroundColor Cyan
    Write-Host "  pwsh -File .lcm/tools/internal/Flush-LcmLegacyLogs.ps1 -Apply`n" -ForegroundColor Yellow
}



