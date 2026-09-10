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
Module: Clear-BCReviewTemp.ps1
Purpose: User command to inspect and clean up Beyond Compare temp review directories in BC_Review scratch.
Path: tools/Clear-BCReviewTemp.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.5.1
Date: 2026-09-10
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
    Write-Host "  pwsh Workspace_Inventory/tools/Clear-BCReviewTemp.ps1 [-All] [-Purge] [-OlderThanHours <int>] [-NoExplorer] [-h]"
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
$scratchReviewDir = Join-Path $workspaceRoot 'Workspace_Inventory\scratch\BC_Review'
$legacyTempParent = Join-Path $env:TEMP 'BC_Review'

$searchDirs = @()
if (Test-Path -LiteralPath $scratchReviewDir) { $searchDirs += $scratchReviewDir }
if (Test-Path -LiteralPath $legacyTempParent) { $searchDirs += $legacyTempParent }

if ($searchDirs.Count -eq 0) {
    Write-Host "No BC_Review scratch directories found." -ForegroundColor Cyan
    return
}

$rawDirs = @()
foreach ($sd in $searchDirs) {
    $rawDirs += @(Get-ChildItem -Path $sd -Directory -ErrorAction SilentlyContinue)
}

# Load session metadata for each directory
$sessionEntries = foreach ($dir in $rawDirs) {
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
}

# ==============================================================================
# 2. Deletions (Executed FIRST based on exact SessionStarted timestamp)
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
        Write-Host "Only 1 review folder exists. Nothing to purge. (Use -All / -a to remove all)." -ForegroundColor Yellow
    }
}
elseif ($hasOlderThan) {
    $cutoff = (Get-Date).AddHours(-$OlderThanHours)
    $toDelete = @($sessionEntries | Where-Object { $_.SessionStarted -lt $cutoff } | ForEach-Object { $_.DirectoryObject })
    Write-Host "Action: Purging $($toDelete.Count) folder(s) older than $OlderThanHours hour(s) (Cutoff: $cutoff)..." -ForegroundColor Yellow
}

if ($toDelete.Count -gt 0) {
    $deletedCount = 0
    foreach ($target in $toDelete) {
        if ($PSCmdlet.ShouldProcess($target.FullName, "Delete BC_Review temp directory")) {
            try {
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
    # Refresh directory list after deletion
    $rawDirs = @(Get-ChildItem -Path $tempParent -Directory -ErrorAction SilentlyContinue)
    $sessionEntries = @($sessionEntries | Where-Object { Test-Path $_.DirectoryObject.FullName })
}

# ==============================================================================
# 3. Report & Status Table
# ==============================================================================
Write-Host "`n==========================================================================================" -ForegroundColor Cyan
Write-Host " Beyond Compare Review Temp Directory Manager: $tempParent" -ForegroundColor Cyan
Write-Host "==========================================================================================" -ForegroundColor Cyan

if ($sessionEntries.Count -gt 0) {
    $sessionEntries | Format-Table Repository, BaseCommit, SessionStarted, FileCount, SizeBytes -AutoSize
} else {
    Write-Host "BC_Review temp directory is empty ($tempParent)." -ForegroundColor Green
}

# ==============================================================================
# 4. Open File Explorer AFTER Deletions (Implicit in ALL cases except -All)
# ==============================================================================
if (-not $All -and -not $NoExplorer) {
    if ($sessionEntries.Count -gt 0) {
        Write-Host "Opening remaining review contents in Windows File Explorer..." -ForegroundColor Green
        Start-Process "explorer.exe" -ArgumentList "`"$tempParent`""
    }
}
elseif ($All) {
    Write-Host "Skipping File Explorer: All review folders were purged." -ForegroundColor Cyan
}
