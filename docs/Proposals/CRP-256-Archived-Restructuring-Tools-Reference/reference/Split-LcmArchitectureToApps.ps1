<#
.SYNOPSIS
    Decomposes monolithic repository tripartite specifications into modular App: # slices.
.DESCRIPTION
    Module: tools/Split-LcmArchitectureToApps.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.0
    Date: 2026-10-13
    Purpose: High-Order Lifecycle Operator that partitions large un-sliced tripartite specifications
             (Architecture.md, Requirements.md, Implementation.md) into cohesive App: # slices per RULE-DOC-007.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Target repository name to partition into Apps')]
    [string]$Repo = '',

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'List of App titles to scaffold/decompose into')]
    [string[]]$AppTitles = @(),

    [Parameter(Mandatory = $false, HelpMessage = 'Partition into dedicated docs/App#<N>-<Slug>/ subdirectories (default: false)')]
    [switch]$SplitDocs = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root path')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or [string]::IsNullOrWhiteSpace($Repo)) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SPLIT LCM ARCHITECTURE TO APPS (Split-LcmArchitectureToApps)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Decomposes monolithic tripartite specifications into modular App: # slices."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Split-LcmArchitectureToApps.ps1 [-Repo] <str> [[-AppTitles] <str[]>] [-SplitDocs] [-WhatIf] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Repo          : Target repository name (e.g. 'LCM_AI', 'SystemConfiguration')"
    Write-Host "  -AppTitles     : Array of App titles to scaffold (e.g. 'Control Hub', 'Governance Engine')"
    Write-Host "  -SplitDocs     : Partition into dedicated docs/App#<N>-<Slug>/ subdirectories (default: false)"
    Write-Host "  -WorkspaceRoot : Workspace root directory (default: D:\Git_Repositories)"
    Write-Host "  -WhatIf        : Previews the planned decomposition without modifying files"
    Write-Host "  -Help (-h, -?) : Displays this parameter reference"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$targetRepoPath = Join-Path $WorkspaceRoot $Repo
if (-not (Test-Path -LiteralPath $targetRepoPath)) {
    throw "Target repository '$Repo' not found at: $targetRepoPath"
}

$docsDir = Join-Path $targetRepoPath 'docs'
if (-not (Test-Path -LiteralPath $docsDir)) {
    throw "Documentation directory not found at: $docsDir"
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host (" DECOMPOSING SPECIFICATIONS INTO APPS: {0} (SplitDocs: {1})" -f $Repo, $SplitDocs.IsPresent) -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Discover existing Apps
$existingApps = @(Get-LcmApps -Repo $Repo -WorkspaceRoot $WorkspaceRoot)
$currentMaxNum = 0
foreach ($a in $existingApps) {
    if ($a.number -gt $currentMaxNum) { $currentMaxNum = $a.number }
}

Write-Host (" Current registered Apps in {0}: {1} (Max ID: {2})" -f $Repo, $existingApps.Count, $currentMaxNum) -ForegroundColor Cyan

if (@($AppTitles).Count -eq 0) {
    Write-Host " No explicit -AppTitles provided. Scanning codebase for candidates..." -ForegroundColor Yellow
    # Auto-discover candidates from module filenames
    $modulesDir = Join-Path $targetRepoPath 'modules'
    if (Test-Path -LiteralPath $modulesDir) {
        $foundMods = @(Get-ChildItem -Path $modulesDir -Filter "*.psm1" -File)
        foreach ($m in $foundMods) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($m.Name)
            if ($baseName -notmatch 'Core$|Utils$') {
                $AppTitles += $baseName
            }
        }
    }
}

if (@($AppTitles).Count -eq 0) {
    Write-Warning "No App titles specified or auto-discovered. Please pass -AppTitles @('Title 1', 'Title 2')."
    return
}

$minted = @()
$currNum = $currentMaxNum

foreach ($title in $AppTitles) {
    $currNum++
    $appId = "App: $currNum"
    $fullTitle = "$appId - $title"

    $actionDesc = if ($SplitDocs) { "Scaffold dedicated docs/apps/$appId/ tripartite specs" } else { "Scaffold modular section '$fullTitle' across tripartite specs" }
    if ($PSCmdlet.ShouldProcess("$Repo/docs/", $actionDesc)) {
        $appObj = New-LcmApp -Title $title -Repo $Repo -SplitDocs:$SplitDocs -WorkspaceRoot $WorkspaceRoot
        $minted += $appObj
    } else {
        Write-Host (" [WhatIf] Would scaffold {0} across {1}/docs/ (SplitDocs: {2})" -f $fullTitle, $Repo, $SplitDocs.IsPresent) -ForegroundColor Yellow
    }
}

# Sync catalog
if ($minted.Count -gt 0) {
    Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null
    Write-Host "`nUpdated App Catalog for $($Repo):" -ForegroundColor Cyan
    Format-LcmAppsTable -WorkspaceRoot $WorkspaceRoot
}
