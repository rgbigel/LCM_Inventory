[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Purge all review folders (Explorer is skipped in -All mode)')]
    [Alias('a')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Purge older review folders, keeping only the single newest one')]
    [Alias('p')]
    [switch]$Purge,

    [Parameter(Mandatory = $false, HelpMessage = 'Purge review folders older than the specified number of hours')]
    [Alias('o', 'Older')]
    [int]$OlderThanHours,

    [Parameter(Mandatory = $false, HelpMessage = 'Suppress automatically opening Windows File Explorer')]
    [switch]$NoExplorer,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Inspects and cleans up Beyond Compare temp review directories in BC_Review scratch.
.DESCRIPTION
    Module: tools/Clear-BCReviewTemp.ps1
    Purpose: User command and automated lifecycle hook to inspect and clean up Beyond Compare temp review directories in BC_Review scratch.
             Safely preserves and unlinks Approach A directory junctions (ACTIVE_BASELINE and ACTIVE_LIVE) per RULE-PS-018.
    Path: tools/Clear-BCReviewTemp.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.0
    Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CLEAR BEYOND COMPARE TEMP REVIEWS (Clear-BCReviewTemp)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Inspect and clean up Beyond Compare temp review directories in BC_Review scratch."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Clear-BCReviewTemp.ps1 [-All] [-Purge] [-OlderThanHours <int>] [-NoExplorer] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -All             : Purge all review folders (Explorer is skipped in -All mode)"
    Write-Host "  -Purge           : Purge older review folders, keeping only the single newest one"
    Write-Host "  -OlderThanHours  : Purge review folders older than the specified number of hours"
    Write-Host "  -NoExplorer      : Suppress automatically opening Windows File Explorer"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

# ==============================================================================
# 1. Parameter Validation & Mutual Exclusivity Check
# ==============================================================================
$hasOlderThan = $PSBoundParameters.ContainsKey('OlderThanHours')

if ($All -and ($Purge -or $hasOlderThan)) {
    throw "Invalid Parameter Combination: '-All' (-a) cannot be combined with '-Purge' (-p) or '-OlderThanHours' (-o)."
}

if ($Purge -and $hasOlderThan) {
    throw "Invalid Parameter Combination: Please choose either '-Purge' (-p) OR '-OlderThanHours' (-o), not both."
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$scratchReviewDir = Join-Path $workspaceRoot 'LCM_Inventory\scratch\BC_Review'
$legacyTempParent = Join-Path $env:TEMP 'BC_Review'

$searchDirs = @()
if (Test-Path -LiteralPath $scratchReviewDir) { $searchDirs += $scratchReviewDir }
if (Test-Path -LiteralPath $legacyTempParent) { $searchDirs += $legacyTempParent }

if ($searchDirs.Count -eq 0) {
    Write-Host "No BC_Review scratch directories found." -ForegroundColor Cyan
    return
}

# Safely filter out permanent junction bridges (ACTIVE_BASELINE and ACTIVE_LIVE) per RULE-PS-018
$rawDirs = @()
foreach ($sd in $searchDirs) {
    $found = @(Get-ChildItem -Path $sd -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notin @('ACTIVE_BASELINE', 'ACTIVE_LIVE') -and $_.LinkType -ne 'Junction'
    })
    if ($found.Count -gt 0) {
        $rawDirs += $found
    }
}

# Load session metadata for each directory
$sessionEntries = @(foreach ($dir in $rawDirs) {
    $metaFile = Join-Path $dir.FullName ".lcm_review.json"
    $sessionStarted = $dir.CreationTime
    $baseCommit = "-"
    $repoName = $dir.Name

    if (Test-Path -LiteralPath $metaFile) {
        try {
            $meta = Get-Content -LiteralPath $metaFile -Raw | ConvertFrom-Json
            if ($meta.SessionStartedAt) { $sessionStarted = [DateTime]::Parse($meta.SessionStartedAt) }
            if ($meta.BaseCommit) { $baseCommit = $meta.BaseCommit }
            if ($meta.RepositoryName) { $repoName = $meta.RepositoryName }
        } catch { }
    }

    $files = @(Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue)
    $totalBytes = 0
    foreach ($f in $files) { $totalBytes += $f.Length }

    [pscustomobject]@{
        Name             = $dir.Name
        Repository       = $repoName
        BaseCommit       = $baseCommit
        SessionStarted   = $sessionStarted
        FileCount        = $files.Count
        SizeBytes        = $totalBytes
        DirectoryObject  = $dir
    }
})

# ==============================================================================
# 2. Deletions (Executed based on selection criteria)
# ==============================================================================
$toDelete = @()

if ($All) {
    $toDelete = @($sessionEntries | ForEach-Object { $_.DirectoryObject })
    Write-Host "Action: Purging ALL $($sessionEntries.Count) review directory(ies)..." -ForegroundColor Yellow
}
elseif ($Purge) {
    if ($sessionEntries.Count -gt 1) {
        $sorted = $sessionEntries | Sort-Object SessionStarted -Descending
        $toDelete = @($sorted | Select-Object -Skip 1 | ForEach-Object { $_.DirectoryObject })
        Write-Host "Action: Preserving newest session ($($sorted[0].Name)), removing $($toDelete.Count) older folder(s)..." -ForegroundColor Yellow
    } else {
        Write-Host "Only $($sessionEntries.Count) review folder(s) exist. Nothing to purge. (Use -All / -a to remove all)." -ForegroundColor Yellow
    }
}
elseif ($hasOlderThan) {
    $cutoff = (Get-Date).AddHours(-$OlderThanHours)
    $toDelete = @($sessionEntries | Where-Object { $_.SessionStarted -lt $cutoff } | ForEach-Object { $_.DirectoryObject })
    Write-Host "Action: Purging $($toDelete.Count) folder(s) older than $OlderThanHours hour(s) (Cutoff: $cutoff)..." -ForegroundColor Yellow
}

$activeBaselineJunction = Join-Path $scratchReviewDir "ACTIVE_BASELINE"
$activeLiveJunction = Join-Path $scratchReviewDir "ACTIVE_LIVE"

if ($toDelete.Count -gt 0) {
    $deletedCount = 0
    foreach ($target in $toDelete) {
        if ($PSCmdlet.ShouldProcess($target.FullName, "Delete BC_Review temp directory")) {
            try {
                # If ACTIVE_BASELINE currently points to this target, safely unlink junction first
                if (Test-Path -LiteralPath $activeBaselineJunction) {
                    try {
                        $jItem = Get-Item -LiteralPath $activeBaselineJunction -Force -ErrorAction SilentlyContinue
                        if ($jItem -and $jItem.Target -eq $target.FullName) {
                            [System.IO.Directory]::Delete($activeBaselineJunction, $false)
                            Write-Host "Safely unlinked junction ACTIVE_BASELINE (target being deleted)" -ForegroundColor DarkCyan
                        }
                    } catch {}
                }

                # Safely unlink any nested directory junctions before deleting directory tree (RULE-PS-018)
                $nestedJunctions = @(Get-ChildItem -Path $target.FullName -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LinkType -eq 'Junction' })
                foreach ($nj in $nestedJunctions) {
                    try { [System.IO.Directory]::Delete($nj.FullName, $false) } catch {}
                }

                Remove-Item -LiteralPath $target.FullName -Recurse -Force
                Write-Host "Deleted: $($target.Name)" -ForegroundColor Green
                $deletedCount++
            }
            catch {
                Write-Warning "Failed to delete $($target.FullName): $_"
            }
        }
    }
    Write-Host "`nCleanup Complete. Removed $deletedCount folder(s)." -ForegroundColor Green

    # If -All was chosen, also safely unlink ACTIVE_BASELINE if still present
    if ($All -and (Test-Path -LiteralPath $activeBaselineJunction)) {
        try {
            [System.IO.Directory]::Delete($activeBaselineJunction, $false)
            Write-Host "Safely unlinked junction ACTIVE_BASELINE" -ForegroundColor DarkCyan
        } catch {}
    }

    # Refresh directory list after deletion
    $sessionEntries = @($sessionEntries | Where-Object { Test-Path $_.DirectoryObject.FullName })
}

# Clean stale review staging manifests if requested
$reviewsDir = Join-Path $workspaceRoot "LCM_Inventory\data\reviews"
if (Test-Path -LiteralPath $reviewsDir) {
    $stagedManifests = @(Get-ChildItem -Path $reviewsDir -Filter "staged_review_*.json" -ErrorAction SilentlyContinue)
    foreach ($sm in $stagedManifests) {
        if ($All) {
            Remove-Item -LiteralPath $sm.FullName -Force -ErrorAction SilentlyContinue
        } else {
            # If target review root in manifest no longer exists, remove orphan manifest
            try {
                $mJson = Get-Content -LiteralPath $sm.FullName -Raw | ConvertFrom-Json
                if ($mJson.TempReviewRoot -and -not (Test-Path -LiteralPath $mJson.TempReviewRoot)) {
                    Remove-Item -LiteralPath $sm.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "Removed orphan review staging manifest: $($sm.Name)" -ForegroundColor DarkCyan
                }
            } catch {}
        }
    }
}

# ==============================================================================
# 3. Report & Status Table
# ==============================================================================
Write-Host "`n==========================================================================================" -ForegroundColor Cyan
Write-Host " Beyond Compare Review Temp Directory Manager: $scratchReviewDir" -ForegroundColor Cyan
Write-Host "==========================================================================================" -ForegroundColor Cyan

if ($sessionEntries.Count -gt 0) {
    $sessionEntries | Format-Table Repository, BaseCommit, SessionStarted, FileCount, SizeBytes -AutoSize
} else {
    Write-Host "BC_Review temp directory is empty ($scratchReviewDir)." -ForegroundColor Green
}

# ==============================================================================
# 4. Open File Explorer AFTER Deletions (Implicit in ALL cases except -All or -NoExplorer)
# ==============================================================================
if (-not $All -and -not $NoExplorer) {
    if ($sessionEntries.Count -gt 0 -and (Test-Path -LiteralPath $scratchReviewDir)) {
        Write-Host "Opening remaining review contents in Windows File Explorer..." -ForegroundColor Green
        Start-Process "explorer.exe" -ArgumentList "`"$scratchReviewDir`""
    }
}
elseif ($All) {
    Write-Host "Skipping File Explorer: All review folders were purged." -ForegroundColor Cyan
}
